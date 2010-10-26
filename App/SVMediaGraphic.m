//
//  SVMediaGraphic.m
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphic.h"

#import "SVAudio.h"
#import "SVFlash.h"
#import "SVGraphicFactory.h"
#import "KTMaster.h"
#import "SVMediaGraphicInspector.h"
#import "SVMediaRecord.h"
#import "SVImage.h"
#import "KTPage.h"
#import "SVWebEditorHTMLContext.h"
#import "KSWebLocation.h"
#import "SVVideo.h"

#import "NSError+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSURLUtilities.h"


@interface SVMediaGraphic ()

@property(nonatomic, copy) NSString *externalSourceURLString;

- (void)didSetSource;

@property(nonatomic, copy, readwrite) NSNumber *constrainedAspectRatio;

@end


#pragma mark -


@implementation SVMediaGraphic

#pragma mark Init

+ (id)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMediaGraphic *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaGraphic"
                                                           inManagedObjectContext:context];
    [result loadPlugInAsNew:YES];
    return result;
}

- (void)willInsertIntoPage:(KTPage *)page;
{
    // Placeholder image
    if (![self media])
    {
        SVMediaRecord *media = [[page master] makePlaceholdImageMediaWithEntityName:[[self class] mediaEntityName]];
        [self setMedia:media];
        [self setTypeToPublish:[media typeOfFile]];
        // Sizing will be handled in a moment
    }
    
    [super willInsertIntoPage:page];    // calls -makeOriginalSize internally
    
    [self setConstrainProportions:[self isConstrainProportionsEditable]];
    
    
    // Show caption
    if ([[[self textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}

#pragma mark Plug-in

- (NSString *)plugInIdentifier;
{
    // The plug-in to use depends on the type of file you have. Ideally use .codecType as it means the file's content has been better analyzed
    NSString *type = [self codecType];
    if (!type) type = [[self media] typeOfFile];
    if (!type) type = [NSString UTIForFilenameExtension:[[self externalSourceURL] ks_pathExtension]];
    
    
    if ([type conformsToUTI:(NSString *)kUTTypeMovie]
		|| [type conformsToUTI:(NSString *)kUTTypeVideo]
		|| [type isEqualToString:@"unviewable-video"])	// special case for video we can't actually play on this machine
    {
        return @"com.karelia.sandvox.SVVideo";
    }
    else if ([type conformsToUTI:(NSString *)kUTTypeAudio])
    {
        return @"com.karelia.sandvox.SVAudio";
    }
    else if ([type conformsToUTI:@"com.adobe.shockwave-flash"])
    {
        return @"com.karelia.sandvox.SVFlash";
    }
    else
    {
        return @"com.karelia.sandvox.Image";
    }
}

#pragma mark Placement

- (BOOL)isPagelet;
{
    // Images are no longer pagelets once you turn off all additional stuff like title & caption
    if ([[self placement] intValue] == SVGraphicPlacementInline &&
        ![self showsTitle] &&
        ![self showsIntroduction] &&
        ![self showsCaption])
    {
        return NO;
    }
    else
    {
        return [super isPagelet];
    }
}

#pragma mark Media

@dynamic media;
- (void)setMedia:(SVMediaRecord *)media;
{
    [self willChangeValueForKey:@"media"];
    [self setPrimitiveValue:media forKey:@"media"];
    [self didChangeValueForKey:@"media"];
    
    
    [self didSetSource];
}

@dynamic isMediaPlaceholder;

- (void)setMediaWithURL:(NSURL *)URL;
{
    SVMediaRecord *media = nil;
    if (URL)
    {
        media = [SVMediaRecord mediaWithURL:URL
                                 entityName:[[self class] mediaEntityName]
             insertIntoManagedObjectContext:[self managedObjectContext]
                                      error:NULL];
    }
    
    [self replaceMedia:media forKeyPath:@"media"];
}

+ (NSString *)mediaEntityName; { return @"GraphicMedia"; }

#pragma mark External URL

@dynamic externalSourceURLString;
- (void) setExternalSourceURLString:(NSString *)source;
{
    [self willChangeValueForKey:@"externalSourceURLString"];
    [self setPrimitiveValue:source forKey:@"externalSourceURLString"];
    [self didChangeValueForKey:@"externalSourceURLString"];
    
    [self didSetSource];
}

- (NSURL *)externalSourceURL
{
    NSString *string = [self externalSourceURLString];
    return (string) ? [NSURL URLWithString:string] : nil;
}
- (void)setExternalSourceURL:(NSURL *)URL
{
    if (URL) [self replaceMedia:nil forKeyPath:@"media"];
    
    [self setExternalSourceURLString:[URL absoluteString]];
}

#pragma mark Source

- (void)didSetSource;
{
    // Reset poster frame
    [[[self posterFrame] managedObjectContext] deleteObject:[self posterFrame]];
    [self replaceMedia:nil forKeyPath:@"posterFrame"];
    
    
    // Does this change the type?
    NSString *identifier = [self plugInIdentifier];
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:identifier];
    
    if (![[self plugIn] isKindOfClass:[factory plugInClass]])
    {
        NSNumber *width = [self width];
        
        [self loadPlugInAsNew:NO];
        [[self plugIn] awakeFromNew];   // which will probably set size…
        
        // …so bring the width back to desired value
        [self setWidth:width];
    }
    
    
    [[self plugIn] didSetSource];
}

- (NSURL *)sourceURL;
{
    NSURL *result = nil;
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        result = [media fileURL];
        if (!result) result = [media mediaURL];
    }
    else
    {
        result = [self externalSourceURL];
    }
    
    return result;
}

- (BOOL)hasFile; { return YES; }

+ (BOOL)acceptsType:(NSString *)uti; { return NO; }

+ (NSArray *)allowedTypes;
{
    NSMutableSet *result = [NSMutableSet set];
    [result addObjectsFromArray:[SVImage allowedFileTypes]];
    [result addObjectsFromArray:[SVVideo allowedFileTypes]];
    [result addObjectsFromArray:[SVAudio allowedFileTypes]];
    [result addObjectsFromArray:[SVFlash allowedFileTypes]];
    
	return [result allObjects];
}

- (BOOL)validateSource:(NSError **)error;
{
    // Must have media OR external URL as soure. #92086
    if (![self media] && ![self externalSourceURL])
    {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                               code:NSValidationMissingMandatoryPropertyError
                               localizedDescription:@"Must have either media or external URL as source"];
        
        return NO;
    }
    
    return YES;
}

#pragma mark Poster Frame

@dynamic posterFrame;
- (BOOL)validatePosterFrame:(SVMediaRecord **)media error:(NSError **)error;
{
    BOOL result = [[self plugIn] validatePosterFrame:*media];
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationMissingMandatoryPropertyError localizedDescription:@"Plug-in doesn't want a poster image"];
    }
    
    return result;
}

#pragma mark Media Type

- (NSString *)codecType; { return [self extensiblePropertyForKey:@"codecType"]; }
- (void)setCodecType:(NSString *)type;
{
    if (type)
    {
        [self setExtensibleProperty:type forKey:@"codecType"];
    }
    else
    {
        [self removeExtensiblePropertyForKey:@"codecType"];
    }
}

- (BOOL)usesExtensiblePropertiesForUndefinedKey:(NSString *)key;
{
    return ([key isEqualToString:@"codecType"] ?
            YES :
            [super usesExtensiblePropertiesForUndefinedKey:key]);
}

@dynamic typeToPublish;
- (BOOL)validateTypeToPublish:(NSString **)type error:(NSError **)error;
{
    BOOL result = [[self plugIn] validateTypeToPublish:*type];
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationMissingMandatoryPropertyError localizedDescription:@"typeToPublish is non-optional for images"];
    }
    
    return result;
}

#pragma mark Size

- (void)setSize:(NSSize)size;
{
    if ([self constrainProportions])
    {
        CGFloat constraintRatio = [[self constrainedAspectRatio] floatValue];
        CGFloat aspectRatio = size.width / size.height;
        
        if (aspectRatio < constraintRatio)
        {
            [self setHeight:[NSNumber numberWithFloat:size.height]];
        }
        else
        {
            [self setWidth:[NSNumber numberWithFloat:size.width]];
        }
    }
    else
    {
        [self setWidth:[NSNumber numberWithFloat:size.width]];
        [self setHeight:[NSNumber numberWithFloat:size.height]];
    }
}

- (BOOL)constrainProportions { return [self constrainedAspectRatio] != nil; }
- (void)setConstrainProportions:(BOOL)constrainProportions;
{
    if (constrainProportions)
    {
        // Doesn't make sense to constrain proportions unless both values are known
        OBASSERT([[self height] intValue] > 0);
        OBASSERT([[self width] intValue] > 0);
        
        CGFloat aspectRatio = [[self width] floatValue] / [[self height] floatValue];
        [self setConstrainedAspectRatio:[NSNumber numberWithFloat:aspectRatio]];
    }
    else
    {
        [self setConstrainedAspectRatio:nil];
    }
}

+ (NSSet *)keyPathsForValuesAffectingConstrainProportions;
{
    return [NSSet setWithObject:@"constrainedAspectRatio"];
}

@dynamic constrainedAspectRatio;

- (BOOL)isConstrainProportionsEditable;
{
    // Should only be possible to turn it on once size is known
    BOOL result = ([[self width] integerValue] > 0 &&
                   [[self height] integerValue] > 0 &&
                   [[self plugIn] isConstrainProportionsEditable]);
    
    return result;
}

@dynamic naturalWidth;
@dynamic naturalHeight;

- (void)makeOriginalSize;
{
    BOOL constrainProportions = [self constrainProportions];
    [self setConstrainProportions:NO];  // temporarily turn off so we get desired size.
    
    [super makeOriginalSize];   // calls through to the plug-in's -makeOriginalSize method
    
    [self setConstrainProportions:constrainProportions];
}

#pragma mark Size, inherited

- (void)setWidth:(NSNumber *)width;
{
    [self willChangeValueForKey:@"width"];
    [self setPrimitiveValue:width forKey:@"width"];
    
    NSNumber *aspectRatio = [self constrainedAspectRatio];
    if (aspectRatio)
    {
        NSUInteger height = ([width floatValue] / [aspectRatio floatValue]);
        
        [self willChangeValueForKey:@"height"];
        [self setPrimitiveValue:[NSNumber numberWithUnsignedInteger:height] forKey:@"height"];
        [self didChangeValueForKey:@"height"];
    }
    
    [self didChangeValueForKey:@"width"];
}
- (BOOL)validateWidth:(NSNumber **)width error:(NSError **)error;
{
    // SVGraphic.width is optional. For media graphics it becomes compulsory unless using external URL
    BOOL result = (*width != nil || (![self media] && [self externalSourceURL]));
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSValidationMissingMandatoryPropertyError
                     localizedDescription:@"width is a mandatory property"];
    }
    
    return result;
}

- (void)setHeight:(NSNumber *)height;
{
    [self willChangeValueForKey:@"height"];
    [self setPrimitiveValue:height forKey:@"height"];
    
    NSNumber *aspectRatio = [self constrainedAspectRatio];
    if (aspectRatio)
    {
        NSUInteger width = ([height floatValue] * [aspectRatio floatValue]);
        
        [self willChangeValueForKey:@"width"];
        [self setPrimitiveValue:[NSNumber numberWithUnsignedInteger:width] forKey:@"width"];
        [self didChangeValueForKey:@"width"];
    }
    
    [self didChangeValueForKey:@"height"];
}
- (BOOL)validateHeight:(NSNumber **)height error:(NSError **)error;
{
    // Push off validation to plug-in
    return [[self plugIn] validateHeight:height error:error];
}

#pragma mark Validation

- (BOOL)validateForInsert:(NSError **)error;
{
    if ([super validateForInsert:error])
    {
        return [self validateSource:error];
    }
    
    return NO;
}

- (BOOL)validateForUpdate:(NSError **)error;
{
    if ([super validateForUpdate:error])
    {
        return [self validateSource:error];
    }
    
    return NO;
}

#pragma mark HTML

- (BOOL)shouldWriteHTMLInline; { return [[self plugIn] shouldWriteHTMLInline]; }

- (BOOL)canWriteHTMLInline; { return true; }		// all of these can be figure-content

#pragma mark Inspector

- (Class)inspectorFactoryClass; { return [[self plugIn] class]; }

- (id)objectToInspect; { return self; }

#pragma mark Thumbnail

- (id <SVMedia>)thumbnailMedia;
{
    return [[self plugIn] thumbnailMedia];	// video may want to return poster frame
}

- (id)imageRepresentation;
{
	return [[self plugIn] imageRepresentation];
}

- (NSString *)imageRepresentationType
{
	return [[self plugIn] imageRepresentationType];
}

- (CGFloat)thumbnailAspectRatio;
{
    CGFloat result;
    
    if ([self constrainedAspectRatio])
    {
        result = [[self constrainedAspectRatio] floatValue];
    }
    else
    {
        result = [[self width] floatValue] / [[self height] floatValue];
    }
    
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingImageRepresentation { return [NSSet setWithObject:@"media"]; }

#pragma mark RSS Enclosure

- (id <SVEnclosure>)enclosure;
{
	return [self plugIn];
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Write image data
    SVMediaRecord *media = [self media];
    
    NSData *data = [NSData newDataWithContentsOfMedia:media];
    [propertyList setValue:data forKey:@"fileContents"];
    [data release];
    
    NSURL *URL = [self sourceURL];
    [propertyList setValue:[URL absoluteString] forKey:@"sourceURL"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Pull out image data
    NSData *data = [propertyList objectForKey:@"fileContents"];
    if (data)
    {
        NSString *urlString = [propertyList objectForKey:@"sourceURL"];
        NSURL *url = [NSURL URLWithString:urlString];
        
        SVMediaRecord *media = [SVMediaRecord mediaWithData:data
                                                        URL:url
                                                 entityName:[[self class] mediaEntityName]
                             insertIntoManagedObjectContext:[self managedObjectContext]];
        
        [self setMedia:media];
    }
}

#pragma mark Pasteboard

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    BOOL result = [super awakeFromPasteboardItems:items];
    
    // Can we read a media oject from the pboard?
    SVMediaRecord *media = nil;
    id <SVPasteboardItem> item = [items objectAtIndex:0];
    
    NSURL *URL = [item URL];
    if ([URL isFileURL])
    {
        media = [SVMediaRecord mediaWithURL:URL
                                 entityName:[[self class] mediaEntityName]
             insertIntoManagedObjectContext:[self managedObjectContext]
                                      error:NULL];
    }
    else
    {
        NSString *type = [item availableTypeFromArray:[SVImage allowedFileTypes]];
        if (type)
        {
            // Invent a URL
            NSString *extension = [NSString filenameExtensionForUTI:type];
            
            NSString *path = [[@"/" stringByAppendingPathComponent:@"pasted-file"]
                              stringByAppendingPathExtension:extension];
            
            NSURL *url = [NSURL URLWithScheme:@"sandvox-fake-url"
                                         host:[NSString UUIDString]
                                         path:path];        
            
            media = [SVMediaRecord mediaWithData:[item dataForType:type]
                                             URL:url
                                      entityName:[[self class] mediaEntityName]
                  insertIntoManagedObjectContext:[self managedObjectContext]];
        }
    }
    
    
    // Swap in the new media
    if (media || URL)
    {
        // Reset size & codecType BEFORE media so setting the source can store a new size
        self.naturalWidth = nil;
        self.naturalHeight = nil;
        [self setCodecType:nil];
		
		if (media)
		{
			[self replaceMedia:media forKeyPath:@"media"];
		}
		else
		{
			[self setExternalSourceURL:URL];
		}
		
		NSNumber *oldWidth = [self width];
		[self makeOriginalSize];
		[self setConstrainProportions:[self isConstrainProportionsEditable]];
		if (oldWidth)
		{
			[self setWidth:oldWidth];
		}
		else
		{
			if ([[self width] integerValue] > 200)
			{
				[self setWidth:[NSNumber numberWithInt:200]];
			}
			// If going from external URL to proper media, this means your image is quite probably now 200px wide. Not ideal, but so rare I'm not going to worry abiout it. #92576
		}
    }
    
    [[self plugIn] awakeFromPasteboardItems:items];
    
    return result;
}

@end
