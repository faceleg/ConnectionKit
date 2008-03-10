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
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTMediaContainer.h"
#import "KTMediaManager.h"
#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"
#import "NSMutableSet+Karelia.h"

@interface KTMaster (Private)
- (KTMediaManager *)mediaManager;
@end


@implementation KTMaster

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"editableTimestamp", @"timestampType", @"timestampFormat", @"timestampShowTime", nil]
		triggerChangeNotificationsForDependentKey:@"timestamp"];
	
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
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	// Sort site title
	NSString *html = [self valueForKey:@"siteTitleHTML"];	// just in case there is a site title set here
	if (nil != html)
	{
		NSString *flattenedTitle = [html flattenHTML];
		NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:flattenedTitle];
		[self setPrimitiveValue:[attrString archivableData] forKey:@"siteTitleAttributed"];
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
	NSString *escaped = [value escapedEntities];
	[self setWrappedValue:escaped forKey:@"siteTitleHTML"];
	
	NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:value];
	
	[self setWrappedValue:[attrString archivableData] forKey:@"siteTitleAttributed"];
}

- (NSString *)siteSubtitleText	// get subtitle, but without attributes ... by flattening the HTML
{
	NSString *result = [[self valueForKey:@"siteSubtitleHTML"] flattenHTML];
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
	NSString *siteTitleText = [value flattenHTML];
	NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:siteTitleText];
	
	[self setPrimitiveValue:[attrString archivableData] forKey:@"siteTitleAttributed"];
}

#pragma mark -
#pragma mark Footer

- (NSString *)copyrightHTML
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"copyrightHTML" language:[self valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"copyrightHTML", nil, [NSBundle mainBundle], @"<p>Parting Words (copyright, contact information, etc.)</p>", @"Default text for page bottom")];
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
		result = [KTDesign pluginWithIdentifier:identifier];
		[self setPrimitiveValue:result forKey:@"design"];
	}
	
	return result;
}

- (NSManagedObject *)_designPublishInfoWithDesign:(KTDesign *)design
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	
	// Look to see if there is an existing DesignPublishingInfo object
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", [design identifier]];
	NSError *error = nil;
	NSArray *existingDesigns = [moc objectsWithEntityName:@"DesignPublishingInfo" predicate:predicate error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	NSManagedObject *result = [existingDesigns firstObjectOrNilIfEmpty];
	
	
	// If no existing design was found, create a new object
	if (!result)
	{
		result = [NSEntityDescription insertNewObjectForEntityForName:@"DesignPublishingInfo" inManagedObjectContext:moc];
		[result setValue:[design identifier] forKey:@"identifier"];
	}
	
	
	return result;
}

- (void)setDesign:(KTDesign *)design
{
	// We can't currently handle designs with no identifier. Otherwise, how would we refer to it in the model?
	NSAssert1([design identifier], @"Design %@ has no identifier", [design description]);
	
	[self willChangeValueForKey:@"design"];
	[self setPrimitiveValue:design forKey:@"design"];
	[self didChangeValueForKey:@"design"];
	
	[self setValue:[self _designPublishInfoWithDesign:design] forKey:@"designPublishingInfo"];
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

/*	Like -setBannerImage but crops the media to fit first, as the design likes it
 */
- (void)setBannerImageFromSourceMedia:(KTMediaContainer *)media
{
	KTMediaContainer *banner = [media imageCroppedToSize:[[self design] bannerSize] alignment:NSImageAlignTop];
	[self setBannerImage:banner];
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
	NSParameterAssert(timestampType == KTTimestampCreationDate || timestampType == KTTimestampModificationDate);
	
	[self setWrappedInteger:timestampType forKey:@"timestampType"];
	
	// Update pages to the new style
	NSSet *pages = [self valueForKey:@"pages"];
	[pages makeObjectsPerformSelector:@selector(reloadEditableTimestamp)];
}

#pragma mark -
#pragma mark CSS

- (NSString *)masterCSSForPurpose:(int)generationPurpose;
{
	NSString *result = nil;
	NSMutableString *buffer = [[NSMutableString alloc] init];
	
	
	// If the user has specified a custom banner and the design supports it, load it in
	KTMediaContainer *banner = [self bannerImage];
	if ([[banner file] currentPath])
	{
		NSString *bannerCSSPath = [[[self design] bundle] pathForResource:@"banner" ofType:@"css"];
		if (bannerCSSPath)
		{
			NSString *bannerCSS = [NSMutableString stringWithContentsOfFile:bannerCSSPath];
			if (bannerCSS)
			{
				NSString *bannerPath = nil;
				if (generationPurpose == kGeneratingPreview) {
					bannerPath = [[NSURL fileURLWithPath:[[banner file] currentPath]] absoluteString];
				}
				else {
					NSString *CSSPath = [self publishedMasterCSSPathRelativeToSite];
					NSString *mediaPath = [[[banner file] defaultUpload] valueForKey:@"pathRelativeToSite"];
					
					bannerPath = [[@"/" stringByAppendingString:mediaPath] pathRelativeTo:
								  [@"/" stringByAppendingString:CSSPath]];
				}
				
				bannerCSS = [bannerCSS stringByReplacing:@"banner_image.jpg" with:bannerPath];
				[buffer appendString:bannerCSS];
			}
		}
	}
	
	
	// Tidy up
	if (![buffer isEqualToString:@""])
	{
		result = [NSString stringWithString:buffer];
		[buffer release];
	}
	return result;
}

- (NSString *)publishedMasterCSSPathRelativeToSite
{
	NSString *result = [[[self design] remotePath] stringByAppendingPathComponent:@"master.css"];
	return result;
}

#pragma mark -
#pragma mark Media

- (KTMediaManager *)mediaManager
{
	KTMediaManager *result = [[[self managedObjectContext] document] mediaManager];
	return result;
}

- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet setWithCapacity:4];
	
	[result addObjectIgnoringNil:[self valueForKey:@"bannerImageMediaIdentifier"]];
	[result addObjectIgnoringNil:[self valueForKey:@"logoImageMediaIdentifier"]];
	[result addObjectIgnoringNil:[[[self logoImage] imageToFitSize:NSMakeSize(200.0, 128.0)] identifier]];
	[result addObjectIgnoringNil:[self valueForKey:@"faviconMediaIdentifier"]];
	
	return result;
}

@end
