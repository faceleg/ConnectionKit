//
//  KTMaster.m
//  Marvel
//
//  Created by Mike on 23/10/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMaster+Internal.h"

#import "KT.h"
#import "KTArchivePage.h"
#import "KTDesignPlaceholder.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTImageScalingSettings.h"
#import "SVMediaRecord.h"
#import "SVTitleBox.h"

#import "KTMediaManager.h"
#import "KTMediaContainer.h"

#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"


@interface KTMaster ()
- (KTMediaManager *)mediaManager;

- (void)generatePlaceholderImage;
@end


@implementation KTMaster

#pragma mark -
#pragma mark Initialization

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	
	// Placeholder text
    [self setPrimitiveValue:NSLocalizedString(@"Site Title", "placeholder text")
                     forKey:@"siteTitleHTMLString"];
    [self setPrimitiveValue:NSLocalizedString(@"Site Subtitle", "placeholder text")
                     forKey:@"siteSubtitleHTMLString"];
	
	
	// Prepare our continue reading link
	NSString *continueReadingLink =
		NSLocalizedString(@"Continue reading @@", "Link to read a full article. @@ is replaced with the page title");
	[self setPrimitiveValue:continueReadingLink forKey:@"continueReadingLinkFormat"];
	
	
	// Enable/disable graphical text
	[self setBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"enableImageReplacement"] forKey:@"enableImageReplacement"];
	
	
	// Timestamp
	[self setTimestampFormat:[[NSUserDefaults standardUserDefaults] integerForKey:@"timestampFormat"]];
    
    
    // Code Injection
    KTCodeInjection *codeInjection = [NSEntityDescription insertNewObjectForEntityForName:@"MasterCodeInjection"
                                                                   inManagedObjectContext:[self managedObjectContext]];
    [self setValue:codeInjection forKey:@"codeInjection"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	
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

#pragma mark Site Title

@dynamic siteTitle;

- (void)setSiteTitleWithString:(NSString *)title;
{
    SVTitleBox *text = [self siteTitle];
    if (!text)
    {
        text = [NSEntityDescription insertNewObjectForEntityForName:@"SiteTitle" inManagedObjectContext:[self managedObjectContext]];
        [self setSiteTitle:text];
    }
    [text setText:title];
}

#pragma mark Site Subtitle

@dynamic siteSubtitle;

- (void)setSiteSubtitleWithString:(NSString *)title;
{
    SVTitleBox *text = [self siteSubtitle];
    if (!text)
    {
        text = [NSEntityDescription insertNewObjectForEntityForName:@"SiteSubtitle" inManagedObjectContext:[self managedObjectContext]];
        [self setSiteSubtitle:text];
    }
    [text setText:title];
}

#pragma mark Footer

@dynamic footer;

- (void)setFooterWithString:(NSString *)title;
{
    SVTitleBox *text = [self footer];
    if (!text)
    {
        text = [NSEntityDescription insertNewObjectForEntityForName:@"Footer" inManagedObjectContext:[self managedObjectContext]];
        [self setFooter:text];
    }
    [text setText:title];
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
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert setIcon:[NSApp applicationIconImage]];
		[alert runModal];	
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
    
    NSURL *siteURL = [[[[(NSSet *)[self valueForKey:@"pages"] anyObject] site] hostProperties] siteURL];	// May be nil
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

- (NSString *)bannerCSSForPurpose:(KTHTMLGenerationPurpose)generationPurpose
{
	NSString *result = nil;
	
	// If the user has specified a custom banner and the design supports it, load it in
	KTMediaContainer *banner = [self bannerImage];
	if (banner)
	{
		NSDictionary *scalingProperties = [[self design] imageScalingPropertiesForUse:@"bannerImage"];
		OBASSERT(scalingProperties);
		
		// Find the right path
        NSString *bannerURLString = nil;
        if (generationPurpose == kGeneratingPreview)
        {
            bannerURLString = [[[banner file] URLForImageScalingProperties:scalingProperties] absoluteString];
        }
        else
        {
            // FIXME: Update this to new image scaling system
			NSURL *masterCSSURL = [NSURL URLWithString:@"main.css" relativeToURL:[self designDirectoryURL]];
            NSURL *mediaURL = [[[banner file] uploadForScalingProperties:scalingProperties] URL];
            bannerURLString = [mediaURL stringRelativeToURL:masterCSSURL];
        }
        
        NSString *bannerCSSSelector = [[self design] bannerCSSSelector];
        result = [bannerCSSSelector stringByAppendingFormat:@" { background-image: url(\"%@\"); }\n", bannerURLString];
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

#pragma mark -
#pragma mark Favicon

@dynamic faviconMedia;

- (void)setFaviconWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one
{
    if ([self faviconMedia]) [[self managedObjectContext] deleteObject:[self faviconMedia]];
    
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:URL entityName:@"Favicon" insertIntoManagedObjectContext:[self managedObjectContext] error:NULL];
    [self setFaviconMedia:media];
}

/*	If anyone tries to clear the favicon, actually reset it to the default instead
 */
- (BOOL)mediaContainerShouldRemoveFile:(KTMediaContainer *)mediaContainer
{
	BOOL result = YES;
	
	return result;
}

#pragma mark -
#pragma mark Timestamp

- (NSDateFormatterStyle)timestampFormat { return [self wrappedIntegerForKey:@"timestampFormat"]; }

- (void)setTimestampFormat:(NSDateFormatterStyle)format
{
	[self setWrappedInteger:format forKey:@"timestampFormat"];
}

@dynamic timestampShowTime;

#pragma mark -
#pragma mark Language

- (NSString *)language { return [self wrappedValueForKey:@"language"]; }

- (void)setLanguage:(NSString *)language
{
    [self setWrappedValue:language forKey:@"language"];
    
    // Also update archive page titles to match
    NSArray *archivePages = [KTArchivePage allPagesInManagedObjectContext:[self managedObjectContext]];
    [archivePages makeObjectsPerformSelector:@selector(updateTitle)];
}

#pragma mark -
#pragma mark CSS

- (NSData *)publishedDesignCSSDigest
{
    return [self valueForUndefinedKey:@"publishedDesignCSSDigest"];
}

- (void)setPublishedDesignCSSDigest:(NSData *)digest
{
    [self setValue:digest forUndefinedKey:@"publishedDesignCSSDigest"];
}

#pragma mark -
#pragma mark Site Outline

- (KTCodeInjection *)codeInjection
{
    return [self wrappedValueForKey:@"codeInjection"];
}

#pragma mark -
#pragma mark Media

- (KTMediaManager *)mediaManager
{
	KTSite *site = [[[self valueForKey:@"pages"] anyObject] site];
    KTMediaManager *result = [[site document] mediaManager];
	return result;
}

- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet set];
	
	[result addObjectIgnoringNil:[[self bannerImage] identifier]];
	[result addObjectIgnoringNil:[self valueForKey:@"logoImageMediaIdentifier"]];
	[result addObjectIgnoringNil:[self valueForKey:@"faviconMediaIdentifier"]];
	[result addObjectIgnoringNil:[[self placeholderImage] identifier]];
	
	return result;
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

#pragma mark -
#pragma mark Comments

// TODO: this is kind of hacky, for Sandvox 2 all should be combined
// into the fewest, flexible attributes possible
- (KTCommentsProvider)commentsProvider
{
	return (KTCommentsProvider)[[self valueForUndefinedKey:@"commentsProvider"] intValue];
}

- (void)setCommentsProvider:(KTCommentsProvider)aKTCommentsProvider
{
	NSSet *keys = [NSSet setWithObjects:@"wantsDisqus", @"wantsJSKit", @"wantsHaloscan", @"wantsIntenseDebate", nil];
	[self willChangeValuesForKeys:keys];
	[self setValue:[NSNumber numberWithInt:aKTCommentsProvider] forUndefinedKey:@"commentsProvider"];
	[self didChangeValuesForKeys:keys];
	
	// for backward compatibility with 1.5.4
	if ( KTCommentsProviderJSKit == aKTCommentsProvider )
	{
		[self setValue:[NSNumber numberWithBool:YES] forUndefinedKey:@"wantsJSKit"];
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsHaloscan"];
	}
	else if ( KTCommentsProviderHaloscan == aKTCommentsProvider )
	{
		[self setValue:[NSNumber numberWithBool:YES] forUndefinedKey:@"wantsHaloscan"];
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsJSKit"];
	}
	else
	{
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsHaloscan"];
		[self setValue:[NSNumber numberWithBool:NO] forUndefinedKey:@"wantsJSKit"];
	}
}

- (BOOL)wantsIntenseDebate
{
	return (KTCommentsProviderIntenseDebate == [self commentsProvider]);
}

- (void)setWantsIntenseDebate:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderIntenseDebate];
}

- (NSString *)IntenseDebateAccountID
{
	return [self valueForUndefinedKey:@"IntenseDebateAccountID"];
}

- (void)setIntenseDebateAccountID:(NSString *)aString
{
	[self setValue:aString forUndefinedKey:@"IntenseDebateAccountID"];
}

- (BOOL)wantsDisqus
{
	return (KTCommentsProviderDisqus == [self commentsProvider]);
}

- (void)setWantsDisqus:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderDisqus];
}

- (NSString *)disqusShortName
{
	return [self valueForUndefinedKey:@"disqusShortName"];
}

- (void)setDisqusShortName:(NSString *)aString
{
	[self setValue:aString forUndefinedKey:@"disqusShortName"];
}

- (BOOL)wantsHaloscan
{
	return (KTCommentsProviderHaloscan == [self commentsProvider]);
}

- (void)setWantsHaloscan:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderHaloscan];
}

- (BOOL)wantsJSKit
{
	return (KTCommentsProviderJSKit == [self commentsProvider]);
}

- (void)setWantsJSKit:(BOOL)aBool
{
	[self setCommentsProvider:KTCommentsProviderJSKit];
}

- (NSString *)JSKitModeratorEmail
{
	return [self valueForUndefinedKey:@"JSKitModeratorEmail"];
}

- (void)setJSKitModeratorEmail:(NSString *)aString
{
	[self setValue:aString forUndefinedKey:@"JSKitModeratorEmail"];
}

#pragma mark Support

- (BOOL)canStoreExtensiblePropertyForKey:(NSString *)key
{
    BOOL result = [super canStoreExtensiblePropertyForKey:key];
    
    if ([key isEqualToString:@"placeholderImage"] ||
        [key isEqualToString:@"commentsProvider"])
    {
        result = YES;
    }
    
    return result;
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


#pragma mark -


@implementation KTMaster (Deprecated)

#pragma mark Site Title

- (NSString *)siteTitleHTMLString
{
    return [[self siteTitle] textHTMLString];
}

+ (NSSet *)keyPathsForValuesAffectingSiteTitleHTMLString
{
    return [NSSet setWithObject:@"siteTitle.textHTMLString"];
}

- (NSString *)siteTitleText	// get title, but without attributes
{
	return [[self siteTitle] text];
}

- (void)setSiteTitleText:(NSString *)value
{
	[self setSiteTitleWithString:value];
}

+ (NSSet *)keyPathsForValuesAffectingSiteTitleText
{
    return [NSSet setWithObject:@"siteTitle.textHTMLString"];
}

#pragma mark Site Subtitle

- (NSString *)siteSubtitleHTMLString
{
    return [[self siteSubtitle] textHTMLString];
}

+ (NSSet *)keyPathsForValuesAffectingSiteSubtitleHTMLString
{
    return [NSSet setWithObject:@"siteSubtitle.textHTMLString"];
}

- (NSString *)siteSubtitleText	// get title, but without attributes
{
	return [[self siteSubtitle] text];
}

- (void)setSiteSubtitleText:(NSString *)value
{
	[self setSiteSubtitleWithString:value];
}

+ (NSSet *)keyPathsForValuesAffectingSiteSubtitleText
{
    return [NSSet setWithObject:@"siteSubtitle.textHTMLString"];
}

@end
