#!/usr/bin/env python3
"""Rebuild AppleStores.applStores (the Apple Store list the app reads) from
Apple's current store list.

Usage: apple_stores_plist.py STORES.json ATLAS.DB OLD.applStores OUT.applStores

STORES.json comes from apple_stores_scrape.py.  ATLAS.DB supplies English city
names for stores whose Apple page is in another script.  Every store Apple lists
becomes an "Apple Store" entry; stores no longer listed drop out, and addresses,
coordinates and URLs are taken from Apple's pages.
"""
import json
import math
import plistlib
import re
import sqlite3
import sys
import unicodedata

# Stores whose pages are in a non-Latin script: the names used by the database.
NAMES = {
    "kyoto": "Kyoto", "umeda": "Umeda", "shinsaibashi": "Shinsaibashi", "nagoyasakae": "Nagoya Sakae",
    "ginza": "Ginza", "marunouchi": "Marunouchi", "shinjuku": "Shinjuku", "shibuya": "Shibuya",
    "omotesando": "Omotesando", "kawasaki": "Kawasaki", "fukuoka": "Fukuoka",
    "hanam": "Hanam", "jamsil": "Jamsil", "myeongdong": "Myeongdong", "garosugil": "Garosugil",
    "yeouido": "Yeouido", "gangnam": "Gangnam", "hongdae": "Hongdae",
    "xinyia13": "Xinyi A13", "taipei101": "Taipei 101",
    "globalharbor": "Global Harbor", "hongkongplaza": "Hong Kong Plaza", "wujiaochang": "Wujiaochang",
    "shanghaiiapm": "Shanghai iapm", "pudong": "Pudong", "jingan": "Jing'an", "nanjingeast": "Nanjing East",
    "qibao": "Qibao", "kunming": "Kunming", "xidanjoycity": "Xidan Joy City", "livatbeijing": "Beijing Liv",
    "chaoyangjoycity": "Chaoyang Joy City", "wangfujing": "Wangfujing", "chinacentralmall": "China Central Mall",
    "sanlitun": "Sanlitun", "mixcchengdu": "MixC Chengdu", "taikoolichengdu": "Taikoo Li Chengdu",
    "tianjinjoycity": "Tianjin Joy City", "mixctianjin": "MixC Tianjin", "riverside66tianjin": "Riverside 66 Tianjin",
    "mixchefei": "MixC Hefei", "parc66jinan": "Parc 66 Jinan", "mixcqingdao": "MixC Qingdao",
    "zhujiangnewtown": "Zhujiang New Town", "parccentral": "Parc Central", "mixcshenzhen": "MixC Shenzhen",
    "holidayplazashenzhen": "Holiday Plaza Shenzhen", "uniwalkqianhai": "Uniwalk Qianhai",
    "mixcnanning": "MixC Nanning", "wondercity": "Wonder City", "xinjiekou": "Xinjiekou",
    "xuanwulake": "Xuanwu Lake", "center66wuxi": "Center 66 Wuxi", "suzhou": "Suzhou",
    "mixczhengzhou": "MixC Zhengzhou", "tianyisquare": "Tianyi Square", "westlake": "West Lake",
    "mixchangzhou": "MixC Hangzhou", "mixcwenzhou": "MixC Wenzhou", "wuhan": "Wuhan", "changsha": "Changsha",
    "xiamenlifestylecenter": "Xiamen Lifestyle Center", "tahoeplaza": "Tahoe Plaza",
    "olympia66dalian": "Olympia 66 Dalian", "zhongjiejoycity": "Zhongjie Joy City", "mixcshenyang": "MixC Shenyang",
    "jiefangbei": "Jiefangbei", "mixcchongqing": "MixC Chongqing", "paradisewalkchongqing": "Paradise Walk Chongqing",
}

US_STATES = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR", "California": "CA", "Colorado": "CO",
    "Connecticut": "CT", "Delaware": "DE", "District of Columbia": "DC", "Florida": "FL", "Georgia": "GA",
    "Hawaii": "HI", "Idaho": "ID", "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
    "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD", "Massachusetts": "MA",
    "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS", "Missouri": "MO", "Montana": "MT",
    "Nebraska": "NE", "Nevada": "NV", "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM",
    "New York": "NY", "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
    "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC", "South Dakota": "SD",
    "Tennessee": "TN", "Texas": "TX", "Utah": "UT", "Vermont": "VT", "Virginia": "VA", "Washington": "WA",
    "West Virginia": "WV", "Wisconsin": "WI", "Wyoming": "WY", "Puerto Rico": "PR",
}
AU_STATES = {
    "Australian Capital Territory": "ACT", "New South Wales": "NSW", "Northern Territory": "NT",
    "Queensland": "QLD", "South Australia": "SA", "Tasmania": "TAS", "Victoria": "VIC", "Western Australia": "WA",
}
NON_LATIN = {"Japan", "China", "South Korea", "Taiwan", "Hong Kong", "Thailand", "Singapore"}
ZIP_FIRST = {"Germany", "Austria", "Switzerland", "Netherlands", "Spain", "Italy", "France", "Belgium", "Sweden"}

ABBR = {
    "st": "street", "ave": "avenue", "av": "avenue", "blvd": "boulevard", "rd": "road", "dr": "drive",
    "drv": "drive", "ln": "lane", "hwy": "highway", "pkwy": "parkway", "ctr": "center", "centre": "center",
    "n": "north", "s": "south", "e": "east", "w": "west", "ste": "suite", "sq": "square", "pl": "place",
    "ct": "court", "cir": "circle", "mt": "mount",
}


def fold(s):
    s = s.replace("ß", "ss")
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def street_tokens(s):
    return [ABBR.get(t, t) for t in fold(s).split()]


def hav(a, b, c, d):
    p = math.pi / 180
    x = math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2
    return 12742 * math.asin(math.sqrt(x))


def clean(s):
    return re.sub(r"\s+", " ", (s or "").replace(" ", " ")).strip()


def address(s):
    street, city, region, zip_ = clean(s["street"]), clean(s["city"]), clean(s["region"]), clean(s["zip"])
    c = s["country"]
    if c == "United States":
        last = "%s, %s %s" % (city, US_STATES.get(region, region), zip_)
    elif c == "Canada":
        last = "%s, %s %s" % (city, region, zip_)
    elif c == "United Kingdom":
        last = "%s, %s" % (city, zip_)
    elif c == "Australia":
        last = "%s %s %s" % (city, AU_STATES.get(region, region), zip_)
    elif c in ZIP_FIRST:
        last = "%s %s" % (zip_, city)
    else:
        last = " ".join(x for x in (city, region if region != city else "", zip_) if x)
    return street + "\n" + last.strip()


def store_name(s):
    n = clean(s["name"])
    if s["slug"] == "appleparkvisitorcenter":
        return "Apple Park Visitor Center"
    if s["slug"] in NAMES:
        return NAMES[s["slug"]]
    if not n.isascii() and not re.search(r"[A-Za-zÀ-ɏ]", n):
        raise SystemExit("no English name for " + s["slug"])
    return n


CITY_NAMES = {
    "京都市": "Kyoto", "大阪市": "Osaka", "名古屋市": "Nagoya", "福岡市": "Fukuoka", "川崎市": "Kawasaki",
    "上海": "Shanghai", "北京": "Beijing", "成都": "Chengdu", "天津": "Tianjin", "合肥": "Hefei", "济南": "Jinan",
    "青岛": "Qingdao", "广州": "Guangzhou", "深圳": "Shenzhen", "南宁": "Nanning", "南京": "Nanjing", "无锡": "Wuxi",
    "苏州": "Suzhou", "郑州": "Zhengzhou", "宁波": "Ningbo", "杭州": "Hangzhou", "温州": "Wenzhou", "武汉": "Wuhan",
    "长沙": "Changsha", "厦门": "Xiamen", "福州": "Fuzhou", "大连": "Dalian", "沈阳": "Shenyang", "重庆": "Chongqing",
    "昆明": "Kunming", "서울": "Seoul", "경기": "Hanam", "台北市": "Taipei", "香港": "Hong Kong",
    "กรุงเทพมหานคร": "Bangkok",
}
TOKYO_REGION = "東京都"


def english_city(db, s):
    city = clean(s["city"])
    if clean(s["region"]) == TOKYO_REGION:
        return "Tokyo"
    if city in CITY_NAMES:
        return CITY_NAMES[city]
    if re.fullmatch(r"[A-Za-z\u00c0-\u024f .'\-]+", city):
        return city
    near = [(hav(s["lat"], s["lon"], r[1], r[2]), r) for r in db.execute(
        "select name,latitude,longitude,coalesce(population,0) from geo_object "
        "where geotype='city' and latitude is not null and abs(latitude-?)<0.5 and abs(longitude-?)<0.5", (s["lat"], s["lon"]))]
    near = [x for x in near if x[0] < 25]
    if near:
        return max(near, key=lambda x: (x[1][3], -x[0]))[1][0]  # the big city the store belongs to
    return s["name"]


def slug_of(url):
    m = re.search(r"retail/(?:[a-z]{2}/)?([a-z0-9_\-]+)/", url or "")
    return m.group(1) if m else None


def main(stores_path, db_path, old_path, out_path):
    stores = json.load(open(stores_path))
    for s in stores:
        s["name"] = store_name(s)
    db = sqlite3.connect(db_path)
    old = plistlib.load(open(old_path, "rb"))
    entries = []
    for s in stores:
        entries.append({
            "AdditionalInfo": "",
            "Address": address(s),
            "AlternativeName": s["name"],
            "CityName": english_city(db, s),
            "DBIndex": -1,
            "InfoPaletteTitle": "Apple Store",
            "Lattitude": round(s["lat"], 5),
            "Longitude": round(s["lon"], 5),
            "MarkerColorAlpha": 1.0,
            "MarkerColorBlue": 1.0,
            "MarkerColorGreen": 0.699999988079071,
            "MarkerColorRed": 0.4000000059604645,
            "MarkerSize": 0,
            "MarkerString": "\uf8ff",
            "URL": s["url"],
        })
    # keep the old order for stores that stay, then the new ones
    def old_pos(e):
        for i, o in enumerate(old["entries"]):
            if hav(e["Lattitude"], e["Longitude"], o["Lattitude"], o["Longitude"]) < 0.9 or \
                    (slug_of(o["URL"]) == slug_of(e["URL"]) and fold(o["CityName"]) == fold(e["CityName"])):
                return i
        return None
    pos = [(old_pos(e), e) for e in entries]
    kept = sorted(((p, e) for p, e in pos if p is not None), key=lambda x: x[0])
    new = sorted((e for p, e in pos if p is None), key=lambda e: (e["URL"].split("/retail/")[0], e["AlternativeName"]))
    gone = [o for o in old["entries"] if not any(
        hav(o["Lattitude"], o["Longitude"], e["Lattitude"], e["Longitude"]) < 0.9 or slug_of(o["URL"]) == slug_of(e["URL"])
        for e in entries)]
    out = {"entries": [e for _, e in kept] + new, "revision": str(int(old["revision"]) + 1)}
    plistlib.dump(out, open(out_path, "wb"))
    print("stores: %d -> %d (%d added, %d removed)" % (len(old["entries"]), len(out["entries"]), len(new), len(gone)))
    print("removed:", ", ".join("%s (%s)" % (o["AlternativeName"], o["CityName"]) for o in gone))


if __name__ == "__main__":
    main(*sys.argv[1:5])
