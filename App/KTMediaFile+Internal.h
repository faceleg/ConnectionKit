//
//  KTMediaFile+MediaManagerPrivate.h
//  Marvel
//
//  Created by Mike on 07/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTMediaFile.h"
#import "KTExternalMediaFile.h"
#import "KTInDocumentMediaFile.h"

#import "KTPasteboardArchiving.h"

#import "CIImage+Karelia.h"


@class KTImageScalingSettings;


@interface KTMediaFile (Internal) <KTPasteboardArchiving>

+ (id)insertNewMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc;

- (NSString *)preferredFileName;

// Scaling
- (NSURL *)URLForImageScaledToSize:(NSSize)size
							  mode:(KSImageScalingMode)scalingMode
						sharpening:(float)sharpening
						  fileType:(NSString *)UTI;
- (NSURL *)URLForImageScalingProperties:(NSDictionary *)properties;
- (NSURLRequest *)URLRequestForImageScalingProperties:(NSDictionary *)properties;

- (NSDictionary *)canonicalImageScalingPropertiesForProperties:(NSDictionary *)properties;
- (KTImageScalingSettings *)canonicalImageScalingSettingsForSettings:(KTImageScalingSettings *)settings;

@end


@interface KTExternalMediaFile (Internal) <KTPasteboardArchiving>
+ (id)insertNewMediaFileWithAlias:(BDAlias *)alias inManagedObjectContext:(NSManagedObjectContext *)moc;
@end