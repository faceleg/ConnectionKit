//
//  KTMediaManager2.h
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString *KTMediaLogDomain;


@class KTDocument;
@class KTMediaContainer;

@interface KTMediaManager : NSObject
{
	KTDocument				*myDocument;
	NSManagedObjectContext	*myMOC;
}

// Basic Accesors
- (KTDocument *)document;
- (NSManagedObjectContext *)managedObjectContext;
- (NSManagedObjectModel *)managedObjectModel;

// Media Container Creation
- (KTMediaContainer *)mediaContainerWithIdentifier:(NSString *)identifier;
- (KTMediaContainer *)mediaContainerWithPath:(NSString *)path;
- (KTMediaContainer *)mediaContainerWithURL:(NSURL *)aURL;
- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename UTI:(NSString *)UTI;
- (KTMediaContainer *)mediaContainerWithImage:(NSImage *)image;
- (KTMediaContainer *)mediaContainerWithDraggingInfo:(id <NSDraggingInfo>)dragInfo preferExternalFile:(BOOL)external;
- (KTMediaContainer *)mediaContainerWithDataSourceDictionary:(NSDictionary *)dataSource;

@end


@interface KTMediaManager (MediaFiles)
- (BOOL)mediaFileShouldBeExternal:(NSString *)path;
+ (BOOL)fileConstituesIMedia:(NSString *)path;
@end


@interface NSManagedObject (MediaManagerGarbageCollector)
- (NSSet *)requiredMediaIdentifiers;
@end
