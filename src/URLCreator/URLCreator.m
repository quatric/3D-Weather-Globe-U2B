// URLCreator.dylib: the plugin DynamicEnvironment loads to build the
// CustomWeather download URLs. The original shipped as ppc + i386 only, so a
// 64-bit app couldn't load it; this is its translation (version 6). The
// server could replace it with a newer one at runtime.
#import <Foundation/Foundation.h>

#define EXPORT __attribute__((visibility("default")))

EXPORT NSString *kRequestLowResMapTemplateString =
	@"http://mackiev:mackiev_maps@images.customweather.com/images/cw/client/mackiev/satellite10/%s_%04d_%04d.jpg";
EXPORT NSString *kRequestMapWithDateAdditionTemplateString = @"&anim.init_offset=%d";
EXPORT NSString *kRequestMapTemplateString =
	@"http://maps.customweather.com/image?SRS=EPSG%%3A4326&REQUEST=GetMap&quality=high&TRANSPARENT=FALSE"
	@"&BGCOLOR=0x000000&LAYERS=global_ir_satellite_10km&ir_satellite.threshold=0&ir_satellite.gain=1.1"
	@"&metric=true&BBOX=%d%%2C+-90%%2C+%d%%2C+90&image_width=%d&FORMAT=image%%2Fjpeg";
// indexed by the app's report number; the rest of the 30 slots are empty
EXPORT NSString *kReportStrings[30] = {
	@"current_conditions", @"extended_forecast", @"expanded_forecast", @"astronomy_forecast", @"severe_warning",
};
EXPORT NSString *kRequestTemplateString_with_coords =
	@"http://xml.customweather.com/xml?product=%@&latitude=%f&longitude=%f&client=%@&client_password=%@";
EXPORT NSString *kRequestTemplateString_with_cwid =
	@"http://xml.customweather.com/xml?product=%@&id=%@&client=%@&client_password=%@";
EXPORT NSString *kClientPassword = @"t3mp";
EXPORT NSString *kClientName = @"alexmak_test";

EXPORT int GetVersion(void)
{
	return 6;
}

// The satellite image for a hemisphere, at the newest 3-hour step not after
// aDate (0 to 7380 minutes back).
EXPORT id GetURLForCloudsDownload(char aWest, id aDate, int aSize)
{
	int seconds = (int)([[NSDate date] timeIntervalSinceReferenceDate] - [aDate timeIntervalSinceReferenceDate]);
	int offset = (seconds / 60 + 90) / 180 * 180;

	if (offset < 0)
		offset = 0;
	else if (offset > 7380)
		offset = 7380;
	return [NSString stringWithFormat:kRequestLowResMapTemplateString, aWest ? "west" : "east", offset, aSize];
}

EXPORT id GetURLForReportDownloadByID(int aID, int aReport)
{
	NSString *product = kReportStrings[aReport];

	if (product == nil)
		return nil;
	return [NSString stringWithFormat:kRequestTemplateString_with_cwid, product,
		[NSString stringWithFormat:@"%d", aID], kClientName, kClientPassword];
}

// aX is the longitude and aY the latitude. Las Vegas is asked for by its
// CustomWeather ID.
EXPORT id GetURLForReportDownload(float aX, float aY, int aReport)
{
	NSString *product = kReportStrings[aReport];
	float dLatitude, dLongitude;

	if (product == nil)
		return nil;
	dLatitude = (float)(36.174999 - aY);
	dLongitude = (float)(-115.136391 - aX);
	if (sqrtf(dLongitude * dLongitude + dLatitude * dLatitude) < 0.04f)
		return GetURLForReportDownloadByID(23032, aReport);
	return [NSString stringWithFormat:kRequestTemplateString_with_coords, product, (double)aY, (double)aX,
		kClientName, kClientPassword];
}

// the downloaded data is used as it is
EXPORT id GetXMLForReportData(id aData)
{
	return aData;
}

EXPORT id GetJPGForCloudsData(id aData)
{
	return aData;
}

EXPORT id GetReportUN(void)
{
	return nil;
}

EXPORT id GetReportP(void)
{
	return nil;
}
