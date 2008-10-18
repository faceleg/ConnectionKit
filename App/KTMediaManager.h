//
//  KTMediaManager2.h
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString *KTMediaLogDomain;


@class KTDocument, KTAbstractElement;
@class KTMediaContainer;

@interface KTMediaManager : NSObject
{
	KTDocument				*myDocument;    // Weak ref
	NSManagedObjectContext	*myMOC;
    
    NSMutableDictionary *myMediaContainerIdentifiersCache;
}

// Basic Accesors
- (KTDocument *)document;
- (NSManagedObjectContext *)managedObjectContext;
+ (NSManagedObjectModel *)managedObjectModel;

@end


@interface KTMediaManager (MediaFiles)
- (BOOL)mediaFileShouldBeExternal:(NSString *)path;
+ (BOOL)fileConstitutesIMedia:(NSString *)path;
@end


@interface KTMediaManager (MediaContainers)

// Media Container Creation
- (KTMediaContainer *)mediaContainerWithIdentifier:(NSString *)identifier;

- (KTMediaContainer *)mediaContainerWithPath:(NSString *)path;
- (KTMediaContainer *)mediaContainerWithURL:(NSURL *)aURL;
- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename fileExtension:(NSString *)extension;
- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename UTI:(NSString *)UTI;
- (KTMediaContainer *)mediaContainerWithImage:(NSImage *)image;
- (KTMediaContainer *)mediaContainerWithDraggingInfo:(id <NSDraggingInfo>)dragInfo preferExternalFile:(BOOL)external;
- (KTMediaContainer *)mediaContainerWithDataSourceDictionary:(NSDictionary *)dataSource;

// Scaling
- (BOOL)scaledImageContainersShouldGenerateMediaFiles;

@end


@interface KTMediaManager (LegacySupport)

- (KTMediaContainer *)mediaContainerWithMediaRefNamed:(NSString *)oldMediaRefName element:(NSManagedObject *)oldElement;

- (NSString *)importLegacyMediaFromString:(NSString *)oldText
                      scalingSettingsName:(NSString *)scalingSettings
                               oldElement:(NSManagedObject *)oldElement
                               newElement:(KTAbstractElement *)newElement;

@end


@interface NSManagedObject (MediaManagerGarbageCollector)
- (NSSet *)requiredMediaIdentifiers;
@end
