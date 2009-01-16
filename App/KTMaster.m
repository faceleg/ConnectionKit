//
//  KTMaster.m
//  Marvel
//
//  Created by Mike on 23/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMaster.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDesignPlaceholder.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTHostProperties.h"
#import "KTImageScalingSettings.h"
#import "KTPersistentStoreCoordinator.h"

#import "KTMediaManager.h"
#import "KTMediaContainer.h"
#import "KTMediaFile.h"

#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSMutableSet+Karelia.h"
#import "NSURL+Karelia.h"


@interface KTMaster (Private)
- (NSString *)bannerCSS:(KTHTMLGenerationPurpose)generationPurpose;

- (KTMediaManager *)mediaManager;

- (void)generatePlaceholderImage;
@end


@implementation KTMaster

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	// Site Outline
	[self setKeys:[NSArray arrayWithObjects:@"codeInjectionBeforeHTML",
											@"codeInjectionBodyTag",
											@"codeInjectionBodyTagEnd",
											@"codeInjectionBodyTagStart",
											@"codeInjectionEarlyHead",
											@"codeInjectionHeadArea", nil]
		triggerChangeNotificationsForDependentKey:@"hasCodeInjection"];
	
	
	//[self setKeys:[NSArray arrayWithObject:@"designPublishingInfo"]
	//	triggerChangeNotificationsForDependentKey:@"design"];
}

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	
	// Prepare our continue reading link
	NSString *continueReadingLink =
		NSLocalizedString(@"Continue reading @@", "Link to read a full article. @@ is replaced with the page title");
	[self setValue:continueReadingLink forKey:@"continueReadingLinkFormat"];
	
	
	// Enable/disable graphical text
	[self setBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"enableImageReplacement"] forKey:@"enableImageReplacement"];
	
	
	// Timestamp
	[self setTimestampFormat:[[NSUserDefaults standardUserDefaults] integerForKey:@"timestampFormat"]];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	// Sort site title
	NSString *html = [self valueForKey:@"siteTitleHTML"];	// just in case there is a site title set here
	if (nil != html)
	{
		NSString *flattenedTitle = [html stringByConvertingHTMLToPlainText];
		NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:flattenedTitle];
		[self setPrimitiveValue:[attrString archivableData] forKey:@"siteTitleAttributed"];
	}
	
	// Existing sites may not have their timestamp format set properly
	if (![self timestampFormat])
	{
		[self setTimestampFormat:[[NSUserDefaults standardUserDefaults] integerForKey:@"timestampFormat"]];
	}
	
	
	// Placeholder
	if (![self placeholderImage])
	{
		[self generatePlaceholderImage];
	}
}

#pragma mark -
#pragma mark Site Title & Subtitle

- (NSString *)siteTitleText	// get title, but without attributes
{
	NSAttributedString *attrString = nil;
	
	id value = [self wrappedValueForKey:@"siteTitleAttributed"];
	if ( nil != value )
	{
		if ( [value isKindOfClass:[NSData class]] )
		{
			attrString = [NSAttributedString attributedStringWithArchivedData:value];
		}
		else if ( [value isKindOfClass:[NSAttributedString class]] )
		{
			attrString = value;
		}
	}
	
    return [attrString string];
}

// Equivalent to above, but where we know it's text that we're getting

// We set attributed title, but since we're giving it plain text, it's just an attributed version of that.

- (void)setSiteTitleText:(NSString *)value
{
	NSString *escaped = [value stringByEscapingHTMLEntities];
	[self setWrappedValue:escaped forKey:@"siteTitleHTML"];
	
	NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:value];
	
	[self setWrappedValue:[attrString archivableData] forKey:@"siteTitleAttributed"];
}

- (NSString *)siteSubtitleText	// get subtitle, but without attributes ... by flattening the HTML
{
	NSString *result = [[self valueForKey:@"siteSubtitleHTML"] stringByConvertingHTMLToPlainText];
	if (!result)
	{
		result = @"";
	}
	
    return result;
}

// Flatten the string and just store a fake attributed string.

- (void)setSiteTitleHTML:(NSString *)value
{
	[self setWrappedValue:value forKey:@"siteTitleHTML"];
	// set siteTitleAttributed LAST
	NSString *siteTitleText = [value stringByConvertingHTMLToPlainText];
	NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:siteTitleText];
	
	[self setPrimitiveValue:[attrString archivableData] forKey:@"siteTitleAttributed"];
}

#pragma mark -
#pragma mark Footer

- (NSString *)copyrightHTML
{
	NSString *result = [self wrappedValueForKey:@"copyrightHTML"];
	if (!result)
	{
		result = [self defaultCopyrightHTML];
	}
	
	return result;
}

- (void)setCopyrightHTML:(NSString *)copyrightHTML
{
	if (!copyrightHTML) copyrightHTML = @"";
	[self setWrappedValue:copyrightHTML forKey:@"copyrightHTML"];
}

- (NSString *)defaultCopyrightHTML
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"copyrightHTML" language:[self valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"copyrightHTML", nil, [NSBundle mainBundle], @"Parting Words (copyright, contact information, etc.)", @"Default text for page bottom")];
	return result;
}

#pragma mark -
#pragma mark Design

- (KTDesign *)design
{
	[self willAccessValueForKey:@"design"];
	KTDesign *result = [self primitiveValueForKey:@"design"];
	[self didAccessValueForKey:@"design"];
	
	if (!result)
	{
		NSString *identifier = [self valueForKeyPath:@"designPublishingInfo.identifier"];
        if (identifier)
        {
            result = [KTDesign pluginWithIdentifier:identifier];
            
            // In the event that the design cannot be found, we create a placeholder object
            if (!result)    
            {
                result = [[[KTDesignPlaceholder alloc] initWithBundleIdentifier:identifier] autorelease];
            }
        }
		
        [self setPrimitiveValue:result forKey:@"design"];
	}
	
	return result;
}

- (NSManagedObject *)_designPublishInfoWithIdentifier:(NSString *)identifier
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	
	// Look to see if there is an existing DesignPublishingInfo object
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
	NSError *error = nil;
	NSArray *existingDesigns = [moc objectsWithEntityName:@"DesignPublishingInfo" predicate:predicate error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	NSManagedObject *result = [existingDesigns lastObject];
	
	
	// If no existing design was found, create a new object
	if (!result)
	{
		result = [NSEntityDescription insertNewObjectForEntityForName:@"DesignPublishingInfo" inManagedObjectContext:moc];
		[result setValue:identifier forKey:@"identifier"];
	}
	
	
	return result;
}

/*  Special private method where you supply ONE of the parameters
 */
- (void)_setDesignBundleIdentifier:(NSString *)identifier xorDesign:(KTDesign *)design
{
    if (!identifier)
    {
        identifier = [design identifier];
        OBASSERT(identifier);
    }
    else if (!design)
    {
        design = [KTDesign pluginWithIdentifier:identifier];
    }
    else
    {
        OBASSERT_NOT_REACHED("You should specify a design OR an identifier");
    }
    
    
    // OK, we have an identifier (and hopefully a design), let's do this thing!
    [self willChangeValueForKey:@"design"];
	[self setPrimitiveValue:design forKey:@"design"];
	[self didChangeValueForKey:@"design"];
	
	[self setValue:[self _designPublishInfoWithIdentifier:identifier] forKey:@"designPublishingInfo"];
	
	
	// Changing design affects placeholder image
	[self generatePlaceholderImage];
}

- (void)setDesign:(KTDesign *)design
{
	OBASSERT(design);
    
    // Currently, we operate this as a neat cover 
	[self _setDesignBundleIdentifier:nil xorDesign:design];
}

/*  This method is used when a design's identifier is known, but the design itself is unavailable. (e.g. importing old docs)
 */
- (void)setDesignBundleIdentifier:(NSString *)identifier
{
    OBPRECONDITION(identifier); 
    
    [self _setDesignBundleIdentifier:identifier xorDesign:nil];
}

- (NSURL *)designDirectoryURL
{
	
    NSString *designDirectoryName = [[self design] remotePath];
    OBASSERT(designDirectoryName);
    
    NSURL *siteURL = [[[[(NSSet *)[self valueForKey:@"pages"] anyObject] documentInfo] hostProperties] siteURL];	// May be nil
    NSURL *result = [NSURL URLWithPath:designDirectoryName relativeToURL:siteURL isDirectory:YES];
	
    OBPOSTCONDITION(result);
	return result;
}

- (NSSize)thumbnailImageSize
{
	KTImageScalingSettings *settings = [[self design] imageScalingSettingsForUse:@"thumbnailImage"];
	NSSize result = [settings size];
	return result;
}

#pragma mark -
#pragma mark Banner

- (KTMediaContainer *)bannerImage
{
	[self willAccessValueForKey:@"bannerImage"];
	KTMediaContainer *result = [self primitiveValueForKey:@"bannerImage"];
	[self didAccessValueForKey:@"bannerImage"];
	
	if (!result)
	{
		NSString *mediaID = [self valueForKey:@"bannerImageMediaIdentifier"];
		if (mediaID)
		{
			result = [[self mediaManager] mediaContainerWithIdentifier:mediaID];
			[self setPrimitiveValue:result forKey:@"bannerImage"];
		}
		else
		{
			[self setPrimitiveValue:[NSNull null] forKey:@"bannerImage"];
		}
	}
	else if ((id)result == [NSNull null])
	{
		result = nil;
	}
	
	return result;
}

- (void)setBannerImage:(KTMediaContainer *)banner
{
	[self willChangeValueForKey:@"bannerImage"];
	[self setPrimitiveValue:banner forKey:@"bannerImage"];
	[self setValue:[banner identifier] forKey:@"bannerImageMediaIdentifier"];
	[self didChangeValueForKey:@"bannerImage"];
}

/*  Provides the banner image already scaled correctly.
 */
- (KTMediaContainer *)scaledBanner
{
    KTMediaContainer *result = nil;
	
	// If the user has specified a custom banner and the design supports it, load it in
	KTMediaContainer *banner = [self bannerImage];
	if ([[banner file] currentPath])
	{
		if ([[self design] allowsBannerSubstitution])
		{
			// Scale the banner
			KTImageScalingSettings *scalingSettings = [[self design] imageScalingSettingsForUse:@"bannerImage"];
			NSDictionary *scalingProperties =
            [NSDictionary dictionaryWithObject:scalingSettings forKey:@"scalingBehavior"];
			result = [banner scaledImageWithProperties:scalingProperties];
		}
	}
	
	
	return result;
}

- (NSString *)bannerCSS:(KTHTMLGenerationPurpose)generationPurpose
{
	NSString *result = nil;
	
	// If the user has specified a custom banner and the design supports it, load it in
	KTMediaContainer *banner = [self scaledBanner];
	if (banner)
	{
		// Find the right path
        NSString *bannerURLString = nil;
        if (generationPurpose == kGeneratingPreview)
        {
            NSString *bannerPath = [[banner file] currentPath];
            if (bannerPath)
            {
                bannerURLString = [NSURL fileURLStringWithPath:bannerPath];
            }
        }
        else
        {
            NSURL *masterCSSURL = [NSURL URLWithString:@"master.css" relativeToURL:[self designDirectoryURL]];
            NSURL *mediaURL = [[[banner file] defaultUpload] URL];
            bannerURLString = [mediaURL stringRelativeToURL:masterCSSURL];
        }
        
        NSString *bannerCSSSelector = [[self design] bannerCSSSelector];
        result = [bannerCSSSelector stringByAppendingFormat:@" { background-image: url(%@); }\n", bannerURLString];
	}
	
	
	return result;
}

#pragma mark -
#pragma mark Logo

- (KTMediaContainer *)logoImage
{
	[self willAccessValueForKey:@"logoImage"];
	KTMediaContainer *result = [self primitiveValueForKey:@"logoImage"];
	[self didAccessValueForKey:@"logoImage"];
	
	// The media may not have been fetched from the store yet. If so, do it!
	if (!result)
	{
		NSString *mediaID = [self valueForKey:@"logoImageMediaIdentifier"];
		if (mediaID)
		{
			result = [[self mediaManager] mediaContainerWithIdentifier:mediaID];
			[self setPrimitiveValue:result forKey:@"logoImage"];
		}
		else
		{
			[self setPrimitiveValue:[NSNull null] forKey:@"logoImage"];
		}
	}
	else if ((id)result == [NSNull null])
	{
		result = nil;
	}
	
	return result;
}

- (void)setLogoImage:(KTMediaContainer *)logo
{
	[self willChangeValueForKey:@"logoImage"];
	[self setPrimitiveValue:logo forKey:@"logoImage"];
	[self setValue:[logo identifier] forKey:@"logoImageMediaIdentifier"];
	[self didChangeValueForKey:@"logoImage"];
}

- (NSSize)logoImageMaxSize	{ return NSMakeSize(200.0, 128.0); }

#pragma mark -
#pragma mark Favicon

- (KTMediaContainer *)favicon
{
	[self willAccessValueForKey:@"favicon"];
	KTMediaContainer *result = [self primitiveValueForKey:@"favicon"];
	[self didAccessValueForKey:@"favicon"];
	
	// The media may not have been fetched from the store yet. If so, do it!
	if (!result)
	{
		NSString *mediaID = [self valueForKey:@"faviconMediaIdentifier"];
		if (mediaID)
		{
			result = [[self mediaManager] mediaContainerWithIdentifier:mediaID];
			[self setPrimitiveValue:result forKey:@"favicon"];
		}
		else
		{
			[self setPrimitiveValue:[NSNull null] forKey:@"favicon"];
		}
	}
	else if ((id)result == [NSNull null])
	{
		result = nil;
	}
	
	return result;
}

- (void)setFavicon:(KTMediaContainer *)favicon;
{
	[self willChangeValueForKey:@"favicon"];
	[self setPrimitiveValue:favicon forKey:@"favicon"];
	[self setValue:[favicon identifier] forKey:@"faviconMediaIdentifier"];
	[self didChangeValueForKey:@"favicon"];
}

- (KTMediaContainer *)scaledFavicon
{
    KTMediaContainer *unscaledFavicon = [self favicon];
    NSDictionary *properties = [[self design] imageScalingPropertiesForUse:@"faviconImage"];
    OBASSERT(properties);
    
    KTMediaContainer *result = [unscaledFavicon scaledImageWithProperties:properties];
    return result;
}

/*	If anyone tries to clear the favicon, actually reset it to the default instead
 */
- (BOOL)mediaContainerShouldRemoveFile:(KTMediaContainer *)mediaContainer
{
	BOOL result = YES;
	
	if ([mediaContainer isEqual:[self favicon]])
	{
		NSString *faviconPath = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
		KTMediaContainer *defaultFavicon = [[self mediaManager] mediaContainerWithPath:faviconPath];
		[self setFavicon:defaultFavicon];
		
		result = NO;
	}
	
	return result;
}

#pragma mark -
#pragma mark Timestamp

- (KTTimestampType)timestampType { return [self wrappedIntegerForKey:@"timestampType"]; }

- (void)setTimestampType:(KTTimestampType)timestampType
{
	OBPRECONDITION(timestampType == KTTimestampCreationDate || timestampType == KTTimestampModificationDate);
	
	[self setWrappedInteger:timestampType forKey:@"timestampType"];
	
	// Update pages to the new style
	NSSet *pages = [self valueForKey:@"pages"];
	[pages makeObjectsPerformSelector:@selector(reloadEditableTimestamp)];
}

- (NSDateFormatterStyle)timestampFormat { return [self wrappedIntegerForKey:@"timestampFormat"]; }

- (void)setTimestampFormat:(NSDateFormatterStyle)format
{
	[self setWrappedInteger:format forKey:@"timestampFormat"];
}

#pragma mark -
#pragma mark Language

- (NSString *)language { return [self wrappedValueForKey:@"language"]; }

#pragma mark -
#pragma mark CSS

- (NSString *)masterCSSForPurpose:(KTHTMLGenerationPurpose)generationPurpose;
{
	NSString *result = nil;
	NSMutableString *buffer = [[[NSMutableString alloc] init] autorelease];
	
	
	// If the user has specified a custom banner and the design supports it, load it in
	NSString *bannerCSS = [self bannerCSS:generationPurpose];
	if (bannerCSS) [buffer appendString:bannerCSS];
	
	
	// Tidy up
	if (![buffer isEqualToString:@""])
	{
		result = [NSString stringWithString:buffer];
	}
	return result;
}

#pragma mark -
#pragma mark Media

- (KTMediaManager *)mediaManager
{
	KTPersistentStoreCoordinator *PSC = (id)[[self managedObjectContext] persistentStoreCoordinator];
	OBASSERT(PSC);
	
	KTMediaManager *result = nil;
	if ([PSC isKindOfClass:[KTPersistentStoreCoordinator class]])
	{
		result = [[PSC document] mediaManager];
	}
	return result;
}

- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet set];
	
	[result addObjectIgnoringNil:[[self bannerImage] identifier]];
    [result addObjectIgnoringNil:[[self scaledBanner] identifier]];
	[result addObjectIgnoringNil:[self valueForKey:@"logoImageMediaIdentifier"]];
	[result addObjectIgnoringNil:[[[self logoImage] imageToFitSize:NSMakeSize(200.0, 128.0)] identifier]];
	[result addObjectIgnoringNil:[self valueForKey:@"faviconMediaIdentifier"]];
    [result addObjectIgnoringNil:[[self scaledFavicon] identifier]];
	[result addObjectIgnoringNil:[[self placeholderImage] identifier]];
	
	return result;
}

#pragma mark -
#pragma mark Code Injection

- (BOOL)hasCodeInjection
{
	NSString *aCodeInjection;
	
	aCodeInjection = [self valueForKey:@"codeInjectionBeforeHTML"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"codeInjectionBodyTag"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"codeInjectionBodyTagEnd"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"codeInjectionBodyTagStart"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"codeInjectionEarlyHead"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"codeInjectionHeadArea"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	return NO;
}

#pragma mark -
#pragma mark Placeholder Image

- (KTMediaContainer *)placeholderImage
{
	return [self valueForUndefinedKey:@"placeholderImage"];
}

- (void)generatePlaceholderImage
{
	// What base image should we use?
	NSString *imagePath = [[self design] placeholderImagePath];
	if (!imagePath || [imagePath isEqualToString:@""])
	{
		imagePath = [[[KSPlugin pluginWithIdentifier:@"sandvox.ImageElement"] bundle]
					 pathForImageResource:@"placeholder"];
	}
	
	
	// Emboss the image
	NSImage *placeholderImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
    if (placeholderImage)
    {
        [placeholderImage embossPlaceholder];
        
        // Create a media container and store it
        KTMediaContainer *placeholderMedia = [[self mediaManager] mediaContainerWithImage:placeholderImage];
        [self setValue:placeholderMedia forKey:@"placeholderImage"];
        
        [placeholderImage release];
    }
}

#pragma mark Comments

- (BOOL)wantsHaloscan
{
	return [[self valueForUndefinedKey:@"wantsHaloscan"] boolValue];
}

- (void)setWantsHaloscan:(BOOL)aBool
{
	[self setValue:[NSNumber numberWithBool:aBool] forUndefinedKey:@"wantsHaloscan"];
}

- (BOOL)wantsJSKit
{
	return [[self valueForUndefinedKey:@"wantsJSKit"] boolValue];
}

- (void)setWantsJSKit:(BOOL)aBool
{
	[self setValue:[NSNumber numberWithBool:aBool] forUndefinedKey:@"wantsJSKit"];
}

@end


#pragma mark -


/*  KTDesign is not publicly exposed to plug-ins. So, we have to mirror any methods they need here.
 */

@implementation KTMaster (PluginAPI)

- (NSDictionary *)imageScalingPropertiesForUse:(NSString *)mediaUse
{
    return [[self design] imageScalingPropertiesForUse:mediaUse];
}

@end
