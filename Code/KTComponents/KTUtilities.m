//
//  KTUtilities.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Miscellaneous utility functions:
 Plugin utilities
 Unique MAC address to identify this computer
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x
 
 IMPLEMENTATION NOTES & CAUTIONS:
	x
 
 TO DO:
	???? Should the plugin stuff be moved to the bundle manager?
 
 */

#import "KTUtilities.h"

#import "NSException+Karelia.h"

#import "Debug.h"
#import "KT.h"

#import "KTAppPlugin.h"
#import "KTAbstractHTMLPlugin.h"
#import "KTAbstractPlugin.h"		// for the benefit of L'izedStringInKTComponents macro
#import "KTManagedObjectContext.h"

#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSError+Karelia.h"
#import "NSString+Karelia.h"

#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/network/IOEthernetInterface.h>
#import <IOKit/network/IONetworkInterface.h>
#import <IOKit/network/IOEthernetController.h>
#import <Carbon/Carbon.h>
#import <Security/Security.h>


// Global variable, initialize it here is a good place

NSString *gFunnyFileName = nil;

@implementation KTUtilities

+ (void) initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	gFunnyFileName = [[NSString stringWithFormat:@".%@.%@", @"WebKit", @"UTF-16"] retain];
	[pool release];
}
	
#pragma mark Core Data

/*! returns an autoreleased core data stack with file at aStoreURL */
+ (NSManagedObjectContext *)contextWithURL:(NSURL *)aStoreURL model:(NSManagedObjectModel *)aModel
{
	NSError *localError = nil;
	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:aModel];
	id store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
										 configuration:nil
												   URL:aStoreURL
											   options:nil
												 error:&localError];
	
	if ( nil == store )
	{
		[coordinator release];
		if ( nil != localError )
		{
			[[NSDocumentController sharedDocumentController] presentError:localError];
		}
		else
		{
			[NSException raise:kKareliaDocumentException 
						format:@"Unable create context from %@", aStoreURL];
		}
		return nil;
	}
	
	//==//NSManagedObjectContext *result = [[NSManagedObjectContext alloc] init];
	KTManagedObjectContext *result = [[KTManagedObjectContext alloc] init];
	[result setPersistentStoreCoordinator:coordinator];
	
	[coordinator release];
	
	return [result autorelease];	
}

/*! returns an autoreleaed model from KTComponents_aVersion.mom */
+ (NSManagedObjectModel *)modelWithVersion:(NSString *)aVersion
{
	// passing in nil for aVersion will return the standard KTComponents model
	
	NSString *resourceName = @"KTComponents";
	if ( nil != aVersion )
	{
		resourceName = [resourceName stringByAppendingString:[NSString stringWithFormat:@"_%@", aVersion]];
	}
	NSString *resourceNameWithExtension = [resourceName stringByAppendingPathExtension:@"mom"];
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForResource:resourceName
									  ofType:@"mom"];
								 //inDirectory:@"Models"];
	NSURL *modelURL = [NSURL fileURLWithPath:path];
	
	if ( nil == modelURL )
	{
		[NSException raise:kKareliaDocumentException 
					format:@"Unable to locate %@", resourceNameWithExtension];
		return nil;
	}
	
	NSManagedObjectModel *result = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	
	if ( nil == result )
	{
		[NSException raise:kKareliaDocumentException 
					format:@"Unable create model from %@", resourceNameWithExtension];
		return nil;
	}
	
	return [result autorelease];
}

/*! returns an autoreleaed model from KTComponents_aVersion.mom with all
	Class references set to NSManagedObject, except Storage classes
*/
+ (NSManagedObjectModel *)genericModelWithVersion:(NSString *)aVersion
{
	NSManagedObjectModel *model = [self modelWithVersion:aVersion];
	[model retain];
	
	if ( nil != model )
	{
		NSEnumerator *e = [[model entities] objectEnumerator];
		NSEntityDescription *entity = nil;
		while ( entity = [e nextObject] )
		{
			//FIXME: these classes no longer exist, is this method still required?
			if ( ![[entity managedObjectClassName] isEqualToString:@"KTStoredDictionary"] 
				 && ![[entity managedObjectClassName] isEqualToString:@"KTStoredArray"]
				 && ![[entity managedObjectClassName] isEqualToString:@"KTStoredSet"] )
			[entity setManagedObjectClassName:[NSManagedObject className]];
		}
	}
	
	return [model autorelease];
}

#pragma mark Keychains
/*!	Get the appropriate keychain password.  Returns null if it couldn't be found or there was some other error
*/




+ (NSString *)keychainPasswordForServer:(NSString *)aServerName account:(NSString *)anAccountName
{
	NSString *result = nil;
	
	const char *serverName = [aServerName UTF8String];
	const char *accountName = [anAccountName UTF8String];
	UInt32 passwordLength;
	void *passwordData;
		
	OSStatus status = SecKeychainFindInternetPassword (
											  NULL, // CFTypeRef keychainOrArray,
											  strlen(serverName), // UInt32 serverNameLength,
											  serverName, // const char *serverName,
											  0, // UInt32 securityDomainLength,
											  NULL, // const char *securityDomain,
											  strlen(accountName), // UInt32 accountNameLength,
											  accountName, // const char *accountName,
											  0, // UInt32 pathLength,
											  NULL, // const char *path,
											  0, // UInt16 port,
											  0, // kSecProtocolTypeAny, // SecProtocolType protocol,
											  0, // kSecAuthenticationTypeAny, // SecAuthenticationType authenticationType,
											  &passwordLength, // UInt32 *passwordLength,
											  &passwordData, // void **passwordData,
											  NULL // SecKeychainItemRef *itemRef
										);														// ASKS FOR AUTHORIZATION
	
	if (noErr == status)
	{
		result = [[[NSString alloc] initWithBytes:passwordData length:passwordLength encoding:NSUTF8StringEncoding] autorelease];
		
		status = SecKeychainItemFreeContent(NULL, passwordData);
	}
	return result;
}


/*!	Set the given password.  Returns YES if successful.
*/

+ (OSStatus)keychainSetPassword:(NSString *)inPassword forServer:(NSString *)aServer account:(NSString *)anAccount
{
	const char *serverName = [aServer UTF8String];
	const char *accountName = [anAccount UTF8String];
	const char *password = [inPassword UTF8String];
	SecKeychainItemRef itemRef;
	
	OSStatus status = SecKeychainFindInternetPassword (
													   NULL, // CFTypeRef keychainOrArray,
													   strlen(serverName), // UInt32 serverNameLength,
													   serverName, // const char *serverName,
													   0, // UInt32 securityDomainLength,
													   NULL, // const char *securityDomain,
													   strlen(accountName), // UInt32 accountNameLength,
													   accountName, // const char *accountName,
													   0, // UInt32 pathLength,
													   NULL, // const char *path,
													   0, // UInt16 port,
													   0, // kSecProtocolTypeAny, // SecProtocolType protocol,
													   0, // kSecAuthenticationTypeAny, // SecAuthenticationType authenticationType,
													   0, // UInt32 *passwordLength,
													   NULL, // void **passwordData,
													   &itemRef // SecKeychainItemRef *itemRef
													   );
	
	if (noErr == status)		// if already there, just modify
	{
		// Modify the keychain entry
		status = SecKeychainItemModifyContent(itemRef, NULL, strlen(password), password);
		CFRelease(itemRef);
	}
	else	// add new item
	{
		status = SecKeychainAddInternetPassword (
												 NULL, // default keychain
												 strlen(serverName), // UInt32 serverNameLength,
												 serverName, // const char *serverName,
												 0, // UInt32 securityDomainLength,
												 NULL, // const char *securityDomain,
												 strlen(accountName), // UInt32 accountNameLength,
												 accountName, // const char *accountName,
												 0, // UInt32 pathLength,
												 NULL, // const char *path,
												 0, // port
												 0, // SecProtocolType protocol,
												 0, // SecAuthenticationType authenticationType,
												 strlen(password), // password length
												 password, // password
												 NULL // item ref
												 );
		
	}
	return status;
}

#if 0

/*!	Get something from InternetConfig
 see file://localhost/Developer/ADC%20Reference%20Library/documentation/Carbon/Reference/Internet_Config/internet_config_ref/constant_12.html

Doesn't seem to really return anything useful anymore.  There may be no way to get the user's email anymore, short of asking mail clients....
*/
+ (NSString *)getICEmailAddress
{
	NSString *result = nil;
	ICInstance theInstance;
	ICAttr junkAttr;
	Str255 icResult;
	OSStatus error;
	long size = sizeof(icResult);
	if (ICStart(&theInstance, 'FooB') == noErr)
	{
		error = ICGetPref(theInstance, kICEmail, &junkAttr, &icResult, &size);
		if (error == noErr)
		{
			result = (NSString *)CFStringCreateWithPascalString( NULL, icResult, kCFStringEncodingUTF8);
			[result autorelease];
		}
	}
	return result;
}
#endif

#pragma mark Plugin Management

/*!	Get plug-ins of some given extension.
	For the app wrapper, use the specified "sister directory" of the plug-ins path.
	(If not specified, use the built-in plug-ins path.)
	We also look in Application Support/Sandvox at all levels
	and also, if the directory is specified, that subdir of the above, e.g. Application Support/Sandvox/Designs
	It's optional to be in the specified sub-directory.

	This is used for plugin bundles, but also for designs
	As of 1.5, the returned objects are KTAppPlugins, not NSBundles
*/
+ (NSDictionary *)pluginsWithExtension:(NSString *)extension sisterDirectory:(NSString *)dirPath
{
    NSMutableDictionary *buffer = [NSMutableDictionary dictionary];
    
	float appVersion = [[[NSBundle mainBundle] version] floatVersion];
    NSString *builtInPlugInsPath = [[NSBundle mainBundle] builtInPlugInsPath];
    
    if ( nil != dirPath & ![dirPath isEqualToString:@"Plugins"] )	// Sister directory of plugins?
	{
		// go up out of plug-ins, down into specified directory
        builtInPlugInsPath = [[builtInPlugInsPath stringByDeletingLastPathComponent]
			stringByAppendingPathComponent:dirPath];
    }
	else
	{
		dirPath = @"PlugIns";		// for looking in app support folder
	}
    
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSAllDomainsMask,YES);
	NSString *subDir = [NSString pathWithComponents:
		[NSArray arrayWithObjects:[NSApplication applicationName], dirPath, nil]];
		
	// Add this sub-dir to each path, along with just the path without the subdir
	NSEnumerator *theEnum = [libraryPaths objectEnumerator];
	NSString *libraryPath;
	NSMutableArray *paths = [NSMutableArray array];
	
	while (nil != (libraryPath = [theEnum nextObject]) )
	{
		[paths addObject:[libraryPath stringByAppendingPathComponent:subDir]];
		[paths addObject:[libraryPath stringByAppendingPathComponent:[NSApplication applicationName]]];
	}

	// Add the app's built-in plug-in path too.
	[paths addObject:builtInPlugInsPath];
	
	// Now go through each folder, backwards -- items in more local user
	// folder override built-in ones.
    NSEnumerator *pathsEnumerator = [paths reverseObjectEnumerator];
    NSString *path;
    
    while ( path = [pathsEnumerator nextObject] ) {
//		NSLog(@"Plugins Checking: %@ for *.%@", path, extension);
        NSEnumerator *pluginsEnumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
        NSString *pluginName;
        while (pluginName = [pluginsEnumerator nextObject])
		{
            NSString *pluginPath = [path stringByAppendingPathComponent:pluginName];
            if ( [[pluginPath pathExtension] isEqualToString:extension] )
			{
                KTAbstractHTMLPlugin *plugin = [KTAppPlugin pluginWithPath:pluginPath];
                if (plugin) 
				{
					[[plugin bundle] principalClass]; // fix for CoreData via bbum WWDC 2005
					NSString *identifier = [plugin identifier];
					if (nil == identifier)
					{
						identifier = pluginName;
					}
					
					// Only use an "override" if its version is >= the built-in version.
					// This way, we can update the version with the app, and it supercedes any
					// specially installed versions.
					KTAppPlugin *alreadyInstalledPlugin = [buffer objectForKey:identifier];
					if (nil != alreadyInstalledPlugin
						|| [[[plugin bundle] version] floatVersion] >= [[alreadyInstalledPlugin version] floatVersion])
					{
						if (nil == [plugin minimumAppVersion]
							|| [[plugin minimumAppVersion] floatVersion] <= appVersion)		// plugin's version must be less/equal than app version, not more!
						{
							[buffer setObject:plugin forKey:identifier];

							if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowSearchPaths"])
							{
								// ALWAYS show an override, regardless of preference, to help with support.  But don't do for DEBUG since it's just clutter to us!
								NSLog(@"Found %@ in %@/", pluginName, [path stringByAbbreviatingWithTildeInPath]);
							}
						}
						else
						{
							NSLog(@"Not loading %@, application version %@ is required",
								  [[[plugin bundle] bundlePath] stringByAbbreviatingWithTildeInPath], [plugin minimumAppVersion]);
						}
					}
                }
            }
        }
    }
    
    if ( 0 == [buffer count] )
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowSearchPaths"])
		{
			// Show item #1 in the list which is going to be the ~/Libary/Application Support/Sandvox SANS "PlugIns" or "Designs"?
			NSLog(@"Searched for '.%@' plugins in %@/", extension, [[paths objectAtIndex:1] stringByAbbreviatingWithTildeInPath]);
		}
		return nil;
    }
    
    return [NSDictionary dictionaryWithDictionary:buffer];
}

#pragma mark File Management

+ (BOOL)createPathIfNecessary:(NSString *)storeDirectory error:(NSError **)outError
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    BOOL success = NO;
    
    int i, c;
    NSArray *components = [storeDirectory pathComponents];
    NSString *current = @"";
    c = [components count];  
    for ( i = 0; i < c; i++ ) 
	{
        NSString *anIndex = [components objectAtIndex:i];
        NSString *next = [current stringByAppendingPathComponent:anIndex];
        current = next;
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:next] ) 
		{
            success = [defaultManager createDirectoryAtPath:next attributes:nil];
            if ( !success ) 
			{
				NSString *errorDescription = [NSString stringWithFormat:NSLocalizedString(@"Unable to create directory at path (%@).",@"Error: Unable to create directory at path (%@)."), next];
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:NSFileWriteUnknownError
								localizedDescription:errorDescription];
                return NO;
            }
        } 
    }
    
    return YES;
}

#pragma mark Other

static kern_return_t FindEthernetInterfaces(io_iterator_t *matchingServices);
static kern_return_t GetMACAddress(io_iterator_t intfIterator, UInt8 *MACAddress);


/*!	return primary ethernet MAC address.  Returns nil if failure.
*/
+ (NSData*)MACAddress
{
	NSData *result = nil;
	
    kern_return_t	kernResult = KERN_SUCCESS; // on PowerPC this is an int (4 bytes)
	/*
	 *	error number layout as follows (see mach/error.h and IOKit/IOReturn.h):
	 *
	 *	hi		 		       lo
	 *	| system(6) | subsystem(12) | code(14) |
	 */
	
    io_iterator_t	intfIterator;
    UInt8		MACAddress[ kIOEthernetAddressSize ];
	
    kernResult = FindEthernetInterfaces(&intfIterator);
    
    if (KERN_SUCCESS != kernResult)
    {
        // NSLog(@"FindEthernetInterfaces returned 0x%08x", kernResult);
    }
    else {
        kernResult = GetMACAddress(intfIterator, MACAddress);
        
        if (KERN_SUCCESS != kernResult)
        {
            //NSLog(@"GetMACAddress returned 0x%08x", kernResult);
        }
		else
		{
			result = [NSData dataWithBytes:MACAddress length:kIOEthernetAddressSize];
		}
    }
    (void) IOObjectRelease(intfIterator);	// Release the iterator.
	return result;
}

@end

#pragma mark Static Support Functions

// Returns an iterator containing the primary (built-in) Ethernet interface. The caller is responsible for
// releasing the iterator after the caller is done with it.
static kern_return_t FindEthernetInterfaces(io_iterator_t *matchingServices)
{
    kern_return_t		kernResult; 
    mach_port_t			masterPort;
    CFMutableDictionaryRef	matchingDict;
    CFMutableDictionaryRef	propertyMatchDict;
    
    // Retrieve the Mach port used to initiate communication with I/O Kit
    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        NSLog(@"IOMasterPort returned %d", kernResult);
        return kernResult;
    }
    
    // Ethernet interfaces are instances of class kIOEthernetInterfaceClass. 
    // IOServiceMatching is a convenience function to create a dictionary with the key kIOProviderClassKey and 
    // the specified value.
    matchingDict = IOServiceMatching(kIOEthernetInterfaceClass);
	
    // Note that another option here would be:
    // matchingDict = IOBSDMatching("en0");
	
    if (NULL == matchingDict)
    {
        NSLog(@"IOServiceMatching returned a NULL dictionary.");
    }
    else {
        // Each IONetworkInterface object has a Boolean property with the key kIOPrimaryInterface. Only the
        // primary (built-in) interface has this property set to TRUE.
        
        // IOServiceGetMatchingServices uses the default matching criteria defined by IOService. This considers
        // only the following properties plus any family-specific matching in this order of precedence 
        // (see IOService::passiveMatch):
        //
        // kIOProviderClassKey (IOServiceMatching)
        // kIONameMatchKey (IOServiceNameMatching)
        // kIOPropertyMatchKey
        // kIOPathMatchKey
        // kIOMatchedServiceCountKey
        // family-specific matching
        // kIOBSDNameKey (IOBSDNameMatching)
        // kIOLocationMatchKey
        
        // The IONetworkingFamily does not define any family-specific matching. This means that in            
        // order to have IOServiceGetMatchingServices consider the kIOPrimaryInterface property, we must
        // add that property to a separate dictionary and then add that to our matching dictionary
        // specifying kIOPropertyMatchKey.
		
        propertyMatchDict = CFDictionaryCreateMutable( kCFAllocatorDefault, 0,
                                                       &kCFTypeDictionaryKeyCallBacks,
                                                       &kCFTypeDictionaryValueCallBacks);
		
        if (NULL == propertyMatchDict)
        {
            NSLog(@"CFDictionaryCreateMutable returned a NULL dictionary.");
        }
        else {
            // Set the value in the dictionary of the property with the given key, or add the key 
            // to the dictionary if it doesn't exist. This call retains the value object passed in.
            CFDictionarySetValue(propertyMatchDict, CFSTR(kIOPrimaryInterface), kCFBooleanTrue); 
            
            // Now add the dictionary containing the matching value for kIOPrimaryInterface to our main
            // matching dictionary. This call will retain propertyMatchDict, so we can release our reference 
            // on propertyMatchDict after adding it to matchingDict.
            CFDictionarySetValue(matchingDict, CFSTR(kIOPropertyMatchKey), propertyMatchDict);
            CFRelease(propertyMatchDict);
        }
    }
    
    // IOServiceGetMatchingServices retains the returned iterator, so release the iterator when we're done with it.
    // IOServiceGetMatchingServices also consumes a reference on the matching dictionary so we don't need to release
    // the dictionary explicitly.
    kernResult = IOServiceGetMatchingServices(masterPort, matchingDict, matchingServices);    
    if (KERN_SUCCESS != kernResult)
    {
        NSLog(@"IOServiceGetMatchingServices returned %d", kernResult);
    }
	
    return kernResult;
}

// Given an iterator across a set of Ethernet interfaces, return the MAC address of the last one.
// If no interfaces are found the MAC address is set to an empty string.
// In this sample the iterator should contain just the primary interface.
static kern_return_t GetMACAddress(io_iterator_t intfIterator, UInt8 *MACAddress)
{
    io_object_t		intfService;
    io_object_t		controllerService;
    kern_return_t	kernResult = KERN_FAILURE;
    
    // Initialize the returned address
    bzero(MACAddress, kIOEthernetAddressSize);
    
    // IOIteratorNext retains the returned object, so release it when we're done with it.
    while (intfService = IOIteratorNext(intfIterator))
    {
        CFTypeRef	MACAddressAsCFData;        
		
        // IONetworkControllers can't be found directly by the IOServiceGetMatchingServices call, 
        // since they are hardware nubs and do not participate in driver matching. In other words,
        // registerService() is never called on them. So we've found the IONetworkInterface and will 
        // get its parent controller by asking for it specifically.
        
        // IORegistryEntryGetParentEntry retains the returned object, so release it when we're done with it.
        kernResult = IORegistryEntryGetParentEntry( intfService,
                                                    kIOServicePlane,
                                                    &controllerService );
		
        if (KERN_SUCCESS != kernResult)
        {
            NSLog(@"IORegistryEntryGetParentEntry returned 0x%08x", kernResult);
        }
        else {
            // Retrieve the MAC address property from the I/O Registry in the form of a CFData
            MACAddressAsCFData = IORegistryEntryCreateCFProperty( controllerService,
                                                                  CFSTR(kIOMACAddress),
                                                                  kCFAllocatorDefault,
                                                                  0);
            if (MACAddressAsCFData)
            {
                // CFShow(MACAddressAsCFData); // for display purposes only; output goes to stderr
                
                // Get the raw bytes of the MAC address from the CFData
                CFDataGetBytes(MACAddressAsCFData, CFRangeMake(0, kIOEthernetAddressSize), MACAddress);
                CFRelease(MACAddressAsCFData);
            }
			
            // Done with the parent Ethernet controller object so we release it.
            (void) IOObjectRelease(controllerService);
        }
        
        // Done with the Ethernet interface object so we release it.
        (void) IOObjectRelease(intfService);
    }
	
    return kernResult;
}

