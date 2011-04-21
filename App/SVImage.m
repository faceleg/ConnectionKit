// 
//  SVImage.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVImage.h"

#import "SVApplicationController.h"
#import "SVHTMLContext.h"
#import "SVLink.h"
#import "SVMediaDOMController.h"
#import "SVMediaGraphicInspector.h"
#import "SVMediaRecord.h"
#import "SVSiteItem.h"
#import "SVTextAttachment.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSBitmapImageRep+Karelia.h"
#import "NSError+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "KSThreadProxy.h"

#import "KSPathUtilities.h"
#import "KSWebLocation.h"


@interface SVImage ()
@end


#pragma mark -


@implementation SVImage 

+ (NSArray *)plugInKeys;
{
    return [[super plugInKeys] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:
                                                              @"alternateText",
                                                              @"link",
                                                              nil]];
}

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // Initial link. #51410
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldIncludeLink"] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"linkImageToOriginal"])
    {
        [self setLink:[[[SVLink alloc] initLinkToFullSizeImageOpensInNewWindow:NO] autorelease]];
    }
}

- (void)dealloc;
{
    [_altText release];
    
    [super dealloc];
}

#pragma mark Metrics

+ (NSOperationQueue*) sharedDimensionCheckQueue;
{
	static NSOperationQueue *sSharedDimensionCheckQueue = nil;
	@synchronized(self)
	{
		if (sSharedDimensionCheckQueue == nil)
		{
			sSharedDimensionCheckQueue = [[NSOperationQueue alloc] init];
		}
	}
	return sSharedDimensionCheckQueue;
}

// Called back on main thread 
- (void)gotSize:(NSSize)aSize;
{
	OBASSERT([NSThread isMainThread]);

	if (aSize.width && aSize.height)
	{
		[self setNaturalWidth:[NSNumber numberWithFloat:aSize.width] height:[NSNumber numberWithFloat:aSize.height]];
	}
}

- (void)getDimensionsFromURL:(NSURL *)aURL		// CALLED FROM OPERATION
{
	OBASSERT(![NSThread isMainThread]);
	OBPRECONDITION(aURL);

	NSSize theSize = NSZeroSize;
	
	CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)aURL, NULL);
	if (source)
	{
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:NO],kCGImageSourceShouldCache,
								 nil];
		
		CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(source,  0, (CFDictionaryRef)options );
		
		if (props)
		{
			NSNumber *height = [((NSDictionary *)props) objectForKey:((NSString *)kCGImagePropertyPixelHeight)];
			NSNumber *width  = [((NSDictionary *)props) objectForKey:((NSString *)kCGImagePropertyPixelWidth)];
			theSize = NSMakeSize(width.intValue, height.intValue);
			
			CFRelease(props);
		}
		CFRelease(source);
	}
	else
	{
		NSLog(@"Bad source: %@", aURL);
	}
	
	[[self ks_proxyOnThread:nil waitUntilDone:NO] gotSize:theSize];
}

- (void)getDimensionsFromRemoteImage;
{
	NSURL *sourceURL = [self externalSourceURL];
	if (sourceURL && [sourceURL scheme])
	{
		// Use imageIO to check the dimensions, on a background thread.
	
		NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
																				selector:@selector(getDimensionsFromURL:)
																				  object:sourceURL];
		[[[self class] sharedDimensionCheckQueue] addOperation:operation];
        [operation release];
	}
	else
	{
		NSLog(@"Unable to get dimensions from %@", sourceURL);
	}
}

- (void)resetNaturalSize;
{
    if ([self media])
    {
        // Store natural size
        CGSize size = IMBImageItemGetSize((id <IMBImageItem>)[self media]);
        
        NSUInteger width = size.width;
        NSUInteger height = size.height;
        
        [self setNaturalWidth:(width ? [NSNumber numberWithUnsignedInt:width] : nil)
                       height:(height ? [NSNumber numberWithUnsignedInt:height] : nil)];
    }
    else if ([self externalSourceURL])
    {
        // External images become auto sized
        [[self container] setConstrainsProportions:NO];
        [self setWidth:nil height:nil];
		
		[self getDimensionsFromRemoteImage];
    }
}

#pragma mark Media

- (void)didSetSource;
{
    [super didSetSource];
    
    // Adjust file type if not valid
    if (![self validateTypeToPublish:[self typeToPublish]])
    {
        [self setTypeToPublish:(NSString *)kUTTypeJPEG];
    }
    
    [self resetNaturalSize];
}

+ (NSArray *)allowedFileTypes
{
	return [NSBitmapImageRep imageTypes];
}

- (BOOL)validateTypeToPublish:(NSString *)type;
{
    BOOL result = ([type isEqualToString:(NSString *)kUTTypeJPEG] ||
                   [type isEqualToString:(NSString *)kUTTypePNG] ||
                   [type isEqualToString:(NSString *)kUTTypeGIF]);
    
    return result;
}

#pragma mark Alt Text

@synthesize alternateText = _altText;

#pragma mark Placement

- (BOOL)canWriteHTMLInline; { return YES; }

+ (NSSet *)keyPathsForValuesAffectingIsPagelet;
{
    return [NSSet setWithObjects:
            @"placement",
            @"showsTitle",
            @"showsIntroduction",
            @"showsCaption", nil];
}

#pragma mark Link

@synthesize link = _link;
- (void)setLink:(SVLink *)link;
{
    link = [link copy];
    [_link release]; _link = link;
    
    [[NSUserDefaults standardUserDefaults] setBool:(link != nil) forKey:@"shouldIncludeLink"];
    if (link)
    {
        [[NSUserDefaults standardUserDefaults] setBool:([link linkType] == SVLinkToFullSizeImage)
                                                forKey:@"linkImageToOriginal"];
    }
}

- (id)serializedValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"link"])
    {
        SVLink *link = [self link];
        // If the link is to a page, actually archive a different link that references the ID-only
        if ([link page])
        {
            link = [SVLink linkWithURLString:[link URLString] openInNewWindow:[link openInNewWindow]];
        }
        
        NSData *data = (link ? [NSKeyedArchiver archivedDataWithRootObject:link] : nil);
        return data;
    }
    else
    {
        return [super serializedValueForKey:key];
    }
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;
{
    if ([key isEqualToString:@"link"])
    {
        SVLink *result = nil;
        if (serializedValue)
        {
            result = [NSKeyedUnarchiver unarchiveObjectWithData:serializedValue];
            
            SVSiteItem *page = [SVSiteItem siteItemForPreviewPath:[result URLString]
                                           inManagedObjectContext:[[self container] managedObjectContext]];
            
            if (page) result = [SVLink linkWithSiteItem:page openInNewWindow:[result openInNewWindow]];
        }
        
        [self setLink:result];
    }
    else
    {
        [super setSerializedValue:serializedValue forKey:key];
    }
}

#pragma mark Publishing

- (NSBitmapImageFileType)storageType;
{
    NSBitmapImageFileType result = [NSBitmapImageRep typeForUTI:[self typeToPublish]];
    return result;
}
- (void) setStorageType:(NSBitmapImageFileType)storageType;
{
    [self setTypeToPublish:[NSBitmapImageRep ks_typeForBitmapImageFileType:storageType]];
}
+ (NSSet *)keyPathsForValuesAffectingStorageType;
{
    return [NSSet setWithObject:@"typeToPublish"];
}

@dynamic compressionFactor;

#pragma mark HTML

- (void)writeImageElement:(SVHTMLContext *)context
{
    // Actually write the image
    NSString *alt = [self alternateText];
    if (!alt) alt = @"";
    
    if ([[self container] shouldWriteHTMLInline]) [[self container] buildClassName:context includeWrap:NO];

    [context buildAttributesForResizableElement:@"img" object:self DOMControllerClass:[SVMediaDOMController class]  sizeDelta:NSZeroSize options:0];
    
    
    // Tooltip for placeholders
    if ([context isForEditing])
    {
        [context pushAttribute:@"title"
                         value:NSLocalizedString(@"This image is a placeholder. Drag a new media file here to replace it.",
                                                                "tooltip")];
    }
    
    
    SVMedia *media = [self media];
    if (media)
    {
        NSString *filename = [[[media preferredUploadPath] lastPathComponent] stringByDeletingPathExtension];
        filename = [filename stringByAppendingString:@"_med"];
        
        NSString *extension = [NSString filenameExtensionForUTI:[self typeToPublish]];
        if (extension) filename = [filename stringByAppendingPathExtension:extension];
        
        NSURL *URL = [context addImageMedia:media
                                      width:[self width]
                                     height:[self height]
                                       type:[self typeToPublish]
                          preferredFilename:filename];
        
        [context writeImageWithSrc:(URL ? [context relativeStringFromURL:URL] : @"")
                               alt:alt
                             width:nil height:nil];// nil sizing because bindSizeToObject: takes care
        
        [context addDependencyOnObject:self keyPath:@"typeToPublish"];
    }
    else
    {
        NSURL *URL = [self externalSourceURL];
        
        [context writeImageWithSrc:(URL ? [context relativeStringFromURL:URL] : @"")
                               alt:alt
                             width:self.container.width
                            height:self.container.height];
    }
    //[context addDependencyOnObject:self keyPath:@"media"];    // don't need, graphic does for us
}

- (void)writeHTML:(SVHTMLContext *)context
{
    // Link
    SVTextAttachment *attachment = [[self container] textAttachment];
    if (attachment && ![[attachment causesWrap] boolValue])
    {
        [[self container] buildWrapClassName:context];
        [self writeImageElement:context];
    }
    else
    {
        if ([[self container] shouldWriteHTMLInline]) [[self container] buildWrapClassName:context];
        
        SVLink *link = [self link];
        if (link)
        {
            NSString *href = @"";
            if ([link linkType] == SVLinkToFullSizeImage)
            {
                NSURL *URL = [context addMedia:[self media]];
                if (URL) href = [context relativeStringFromURL:URL];
            }
            else
            {
                href = [[self link] URLString];
            }
            
            [context startAnchorElementWithHref:href title:nil target:nil rel:nil];
            [self writeImageElement:context];
            [context endElement];
        }
        else
        {
            [self writeImageElement:context];
        }
    }
}

+ (NSString *)elementClassName; { return @"ImageElement"; }
+ (NSString *)contentClassName; { return @"photo"; }

- (BOOL)shouldPublishEditingElementID; { return NO; }

#pragma mark Inspector

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = [[[SVMediaGraphicInspector alloc]
                                          initWithNibName:@"SVImage" bundle:nil]
                                         autorelease];
    
    return result;
}

#pragma mark Thumbnail

- (NSString *)imageRepresentationType;
{
    return ([[self thumbnailMedia] mediaData] ?
            IKImageBrowserNSDataRepresentationType :
            IKImageBrowserNSURLRepresentationType);
}

#pragma mark Pasteboard

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    BOOL result = [super awakeFromPasteboardItems:items];
    
    NSString *title = [[items lastObject] title];
    [self setAlternateText:title];
    
    return result;
}

@end
