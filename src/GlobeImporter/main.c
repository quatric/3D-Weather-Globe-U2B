// The CFPlugIn glue of the Spotlight importer for route files (.smroute).
// Like the original, it's Xcode's Metadata Importer template: a factory that
// hands out an MDImporterInterfaceStruct whose ImporterImportData is
// GetMetadataForFile().
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>

#define PLUGIN_ID "53572418-2503-4A54-B021-BDAA584CED27"

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes,
                           CFStringRef contentTypeUTI, CFStringRef pathToFile);

typedef struct __MetadataImporterPluginType {
	MDImporterInterfaceStruct *conduitInterface;
	CFUUIDRef factoryID;
	UInt32 refCount;
} MetadataImporterPluginType;

static HRESULT MetadataImporterQueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv);
static ULONG MetadataImporterPluginAddRef(void *thisInstance);
static ULONG MetadataImporterPluginRelease(void *thisInstance);

static MDImporterInterfaceStruct testInterfaceFtbl = {
	NULL,
	MetadataImporterQueryInterface,
	MetadataImporterPluginAddRef,
	MetadataImporterPluginRelease,
	GetMetadataForFile
};

static MetadataImporterPluginType *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID)
{
	MetadataImporterPluginType *theNewInstance = malloc(sizeof(MetadataImporterPluginType));
	memset(theNewInstance, 0, sizeof(MetadataImporterPluginType));
	theNewInstance->conduitInterface = &testInterfaceFtbl;
	theNewInstance->factoryID = CFRetain(inFactoryID);
	CFPlugInAddInstanceForFactory(inFactoryID);
	theNewInstance->refCount = 1;
	return theNewInstance;
}

static void DeallocMetadataImporterPluginType(MetadataImporterPluginType *thisInstance)
{
	CFUUIDRef theFactoryID = thisInstance->factoryID;
	free(thisInstance);
	if (theFactoryID) {
		CFPlugInRemoveInstanceForFactory(theFactoryID);
		CFRelease(theFactoryID);
	}
}

static HRESULT MetadataImporterQueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv)
{
	CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);

	if (CFEqual(interfaceID, kMDImporterInterfaceID) || CFEqual(interfaceID, IUnknownUUID)) {
		((MetadataImporterPluginType *)thisInstance)->conduitInterface->AddRef(thisInstance);
		*ppv = thisInstance;
		CFRelease(interfaceID);
		return S_OK;
	}
	*ppv = NULL;
	CFRelease(interfaceID);
	return E_NOINTERFACE;
}

static ULONG MetadataImporterPluginAddRef(void *thisInstance)
{
	return ++((MetadataImporterPluginType *)thisInstance)->refCount;
}

static ULONG MetadataImporterPluginRelease(void *thisInstance)
{
	MetadataImporterPluginType *instance = thisInstance;
	instance->refCount -= 1;
	if (instance->refCount == 0) {
		DeallocMetadataImporterPluginType(instance);
		return 0;
	}
	return instance->refCount;
}

__attribute__((visibility("default")))
void *MetadataImporterPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID)
{
	if (CFEqual(typeID, kMDImporterTypeID)) {
		CFUUIDRef uuid = CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR(PLUGIN_ID));
		MetadataImporterPluginType *result = AllocMetadataImporterPluginType(uuid);
		CFRelease(uuid);
		return result;
	}
	return NULL;
}
