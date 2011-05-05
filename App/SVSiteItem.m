// 
//  SVSiteItem.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVSiteItem.h"

#import "KTDesign.h"
#import "KTHostProperties.h"
#import "SVHTMLContext.h"
#import "SVHTMLTextBlock.h"
#import "SVLink.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "KTPage.h"
#import "KTSite.h"
#import "SVWebEditingURL.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"

#import "KSPathUtilities.h"
#import "KTPublishingEngine.h"


@implementation SVSiteItem 

#pragma mark Identifier

@dynamic uniqueID;

- (NSString *)identifier { return [self uniqueID]; }

+ (SVSiteItem *)siteItemForPreviewPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)context;
{
	SVSiteItem *result = nil;
	
	// skip media objects ... starting or containing Media if it's not a request in the main frame
	if ( NSNotFound == [path rangeOfString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]].location )
	{
		int whereTilde = [path rangeOfString:kKTPageIDDesignator options:NSBackwardsSearch].location;	// special mark internally to look up page IDs
		if (NSNotFound != whereTilde)
		{
			NSString *idString = [path substringFromIndex:whereTilde+[kKTPageIDDesignator length]];
			result = [self pageWithUniqueID:idString inManagedObjectContext:context];
		}
		
        // This logic was in the SVSite equivalent of this method. Still applies?
        /*else if ([path hasSuffix:@"/"])
		{
			result = [self rootPage];
		}*/
	}
	return result;
}


#pragma mark Title

@dynamic title;
- (BOOL)showsTitle; { return YES; }

- (void)writeTitle:(id <SVPlugInContext>)context;   // uses rich txt/html when available
{
    [context writeCharacters:[self title]];
}

#pragma mark Dates

- (void)awakeFromInsert
{
    [super awakeFromInsert];
	
	[self setPrimitiveValue:[NSString shortUUIDString] forKey:@"uniqueID"];
    
    // attributes
	NSDate *now = [NSDate date];
	[self setPrimitiveValue:now forKey:@"creationDate"];
	[self setPrimitiveValue:now forKey:@"modificationDate"];
}

- (NSString *)timestampDescription; { return nil; }

@dynamic creationDate;
@dynamic modificationDate;

- (NSString *)timestampDescriptionWithDate:(NSDate *)date;
{
    NSDateFormatterStyle style = [[self master] timestampFormat];
	BOOL showTime = [[[self master] timestampShowTime] boolValue];
	
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateStyle:style]; 
	
	// Minor adjustments to timestampFormat for the time style
	if (!showTime)
	{
		style = NSDateFormatterNoStyle;
	}
	else
	{
		style = kCFDateFormatterShortStyle;	// downgrade to short to avoid seconds
	}
	[formatter setTimeStyle:style];
	
	NSString *result = [formatter stringForObjectValue:date];
	return result;
}

#pragma mark Keywords

@dynamic keywords;

#pragma mark Navigation

/*	In addition to a standard setter, we must also invalidate old site menu
 */
@dynamic includeInSiteMenu;
- (void)setIncludeInSiteMenu:(NSNumber *)include;
{
	[self setWrappedValue:include forKey:@"includeInSiteMenu"];
	[[self site] invalidatePagesInSiteMenuCache];
}

- (BOOL)shouldIncludeInSiteMenu;    // takes into account draft status etc.
{
    BOOL result = ([[self includeInSiteMenu] boolValue] && 
                   ([self datePublished] || ![self isDraftOrHasDraftAncestor]));
    return result;
}

- (NSString *)menuTitle;
{
    NSString *result = [self customMenuTitle];
    if (![result length])
    {
        result = [self title];
    }
    
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingMenuTitle;
{
    return [NSSet setWithObjects:@"title", @"customMenuTitle", nil];
}

- (NSString *)menuTitleHTMLString;
{
    NSString *result = [self menuTitle];
    
    if ([[[self master] design] menusUseNonBreakingSpaces])
    {
        result = [result stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"];
    }
    
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingMenuTitleHTMLString; { return [NSSet setWithObject:@"menuTitle"]; }

@dynamic customMenuTitle;

@dynamic includeInSiteMap;
@dynamic openInNewWindow;

#pragma mark Drafts and Indexes

@dynamic isDraft;

- (BOOL)isDraftOrHasDraftAncestor
{
	BOOL result = [[self isDraft] boolValue];
	if (!result && [self parentPage] != nil)
	{
		result = [[self parentPage] isDraftOrHasDraftAncestor];
	}
	return result;
}

- (void)setPageOrParentDraft:(BOOL)inDraft	// setter for binding, actually store into isDraft
{
	[self setIsDraft:[NSNumber numberWithBool:inDraft]];
	if (!inDraft)
	{
		// turning off draft -- also mark the family stale since it's no longer a draft
		//[self markStale:kStaleFamily];
	}
}

// Derived accessor of whether page should be excluded from a site map because flag is set, or it's an unpublished draft.

- (BOOL)excludedFromSiteMap
{
	BOOL result = ![[self valueForKey:@"includeInSiteMap"] boolValue];		// exclude from site map?
	if (!result)
	{
		// Not excluded by the flag, see if we should exclude it becuase it's an unpublished draft.		
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		if (![self datePublished] && [self isDraftOrHasDraftAncestor])
		{
			result = YES;	// DON'T include if if hasn't been published before, and if it's draft
		}
	}
	return result;
}

@dynamic includeInIndex;

- (BOOL) isPagePublishableInDemo
{
	NSIndexPath *indexPath = [self indexPath];
	static NSIndexPath *sComparisonIndexPath = nil;
	if (!sComparisonIndexPath)
	{
		NSUInteger indexes[] = { 0, kMaxNumberOfFreePublishedPages - 1 };
		sComparisonIndexPath = [[NSIndexPath alloc] initWithIndexes:indexes length:2];
	}
	
	BOOL result = [indexPath length] <= 2
		&& NSOrderedAscending == [indexPath compare:sComparisonIndexPath];
	return result;
}

#pragma mark URL

@dynamic URL;

- (NSString *)filename; { return nil; }

- (NSString *)preferredFilename;
{
    NSString *result = [self filename];
    
	NSString *fileName = [result stringByDeletingPathExtension];
    NSString *extension = [[result pathExtension] lowercaseString];
    
    result = [[fileName legalizedWebPublishingFileName]
                        stringByAppendingPathExtension:extension];
	return result;
}

/*	Looks at sibling pages and the page title to determine the best possible filename.
 *	Guaranteed to return something unique.
 */
- (NSString *)suggestedFilename;
{
	// The home page's title isn't settable, so keep it constant
	if ([self isRoot]) return nil;
	
	
	// Get the preferred filename by converting to lowercase, spaces to _, & removing everything else
    NSString *result = [self preferredFilename];
    
    
	// Build a list of the file names already taken
	NSMutableSet *unavailableFileNames = [[NSMutableSet alloc] init];
    for (SVSiteItem *anItem in [[self parentPage] childItems])
    {
        if (anItem != self)
        {
            [unavailableFileNames addObjectIgnoringNil:[anItem filename]];
        }
    }
	
    
	// Now munge it to make it unique.  Keep adding a number until we find an open slot.
	NSString *baseFilename = result;
	NSUInteger suffixCount = 2;
	while ([unavailableFileNames containsObject:result])
	{
		result = [baseFilename ks_stringWithPathSuffix:[NSString stringWithFormat:
                                                        @"_%u",
                                                        suffixCount++]];
	}
    
    [unavailableFileNames release];
    
	
	OBPOSTCONDITION(result);
	
	return result;
}

- (BOOL)canPreview { return NO; }

- (NSString *)previewPath
{
	NSString *result = [NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, [self uniqueID]];
	return result;
}

#pragma mark Editing

// used to determine if it's an external link, for page details.
- (SVExternalLink *)externalLinkRepresentation { return nil; }
- (KTPage *)pageRepresentation { return nil; }
- (SVMediaRecord *)mediaRepresentation; { return nil; }



/*	Does the hard graft for -publishedPathRelativeToSite and -uploadPathRelativeToSite.
 *	Should not generally be called outside of KTPage methods.
 */
- (NSString *)pathRelativeToSite
{
	NSString *parentPath = @"";
	if (![self isRoot])
	{
		parentPath = [[self parentPage] pathRelativeToSite];
	}
	
	NSString *relativePath = [self filename];
	NSString *result = @"";
	
	if (relativePath)
	{
		result = [parentPath stringByAppendingPathComponent:relativePath];
		
	}
	return result;
}

- (NSURL *)_baseExampleURL;	// support. Subclasses override to be more specific if need be
{
	// Root is a sepcial case where we just supply the site URL
	NSURL *base = [[[self site] hostProperties] siteURL];
	if (!base)
	{
		base = [NSURL URLWithString:@"http://www.example.com/"];
	}
	NSString *newPath = [[base path] stringByAppendingPathComponent:[[self parentPage] pathRelativeToSite]];
	if ([newPath isEqualToString:@"/"]) newPath = @"";
	NSURL *result = [[[NSURL alloc] initWithScheme:[base scheme] host:[base host] path:newPath] autorelease];
	return result;
}

- (NSString *)baseExampleURLString		// make this work for pages and other things like downloadables
{
	NSString *result = nil;
	NSURL *rootBase = [[[self site] hostProperties] siteURL];
	if (!rootBase)
	{
		result = NSLocalizedString(@"«unspecified»", @"placeholder for site not yet set up for publishing.");
	}
	else
	{
		result = [rootBase absoluteString];
	}
	
	if (![result hasSuffix:@"/"]) result = [result stringByAppendingString:@"/"];
	NSString *path = [[self parentPage] pathRelativeToSite];
	if (path && ![path isEqualToString:@""])
	{
		result = [result stringByAppendingFormat:@"%@/", path];
	}
	return result;
}

#pragma mark Publishing

@dynamic datePublished;

/*	Sends out a KVO notification that the page's URL has changed. Upon the next request for the URL it will be
 *	regenerated and cached.
 *	KTAbstractPage does not support children, so it is up to KTPage to implement the recursive portion.
 *
 *	If the URL is invalid, it can be assumed that the site structure must have changed, so we also post a notification.
 */
- (void)recursivelyInvalidateURL:(BOOL)recursive
{
    // Avoid changing .datePublished unecessarily, since it may have many observers. #110596
    if ([self datePublished]) [self setDatePublished:nil]; // #83550
}

#pragma mark Site

@dynamic site;

- (void)setSite:(KTSite *)site recursively:(BOOL)recursive;
{
    // KTPage adds to this behaviour by recursively calling its descendants too, if requested
    
    // Bail if nothing to do
    if (recursive && [self site] == site) return;
    
    [self setSite:site];
}

@dynamic master;

#pragma mark Tree

- (NSSet *)childItems { return nil; }
- (NSArray *)sortedChildren; { return nil; }

@dynamic parentPage;
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;
{
    BOOL result = (*page != nil);
    if (!result && outError)
    {
        NSDictionary *info = [NSDictionary dictionaryWithObject:@"parentPage is a required property" forKey:NSLocalizedDescriptionKey];
        
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSValidationMissingMandatoryPropertyError
                                    userInfo:info];
    }
    
    return result;
}

- (KTPage *)rootPage;   // searches up the tree till it finds a page with no parent
{
    KTPage *result = [[self parentPage] rootPage];
    return result;
}

- (BOOL)isRoot
{
	BOOL result = ((id)self == [[self site] rootPage]);
	return result;
}

- (BOOL)isDescendantOfCollection:(KTPage *)aPotentialAncestor;
{
	if ([aPotentialAncestor isEqual:self]) return YES;
    
    KTPage *parent = [self parentPage];
	if (nil == parent)		// we are at the root node, so it can't be descended from the given node
	{
		return NO;
	}
	if (aPotentialAncestor == parent)
	{
		return YES;
	}
	return [parent isDescendantOfCollection:aPotentialAncestor];
}

- (BOOL)isDescendantOfItem:(SVSiteItem *)aPotentialAncestor;
{
    BOOL result = NO;
    
    if ([aPotentialAncestor isCollection])
    {
        result = [self isDescendantOfCollection:(KTPage *)aPotentialAncestor];
    }
    
    return result;
}

- (short)childIndex { return [self wrappedIntegerForKey:@"childIndex"]; }

- (void)setChildIndex:(short)index { [self setWrappedInteger:index forKey:@"childIndex"]; }

/*	Returns the page's index path relative to root parent. i.e. the Site object.
 *	This means every index starts with 0 to signify root.
 */
- (NSIndexPath *)indexPath;
{
	NSIndexPath *result = nil;
	
	KTPage *parent = [self parentPage];
	if (parent)
	{
		unsigned index = [[parent sortedChildren] indexOfObjectIdenticalTo:self];
		
        // BUGSID: 30402. NSNotFound really shouldn't happen, but if so we need to track it down.
        if (index == NSNotFound)
        {
            if ([[parent childItems] containsObject:self])
            {
                OBASSERT_NOT_REACHED("parent's -sortedChildren must be out of date");
            }
            else
            {
                NSLog(@"Parent to child relationship is broken.\nChild:\n%@\nDeleted:%d\n",
                      self,                     // Used to be an assertion. Now, we return nil and expect the
                      [self isDeleted]);       // original caller to tidy up.
            }
        }
		else
        {
            NSIndexPath *parentPath = [parent indexPath];
            result = [parentPath indexPathByAddingIndex:index];
        }
	}
	else if ([self isRoot])
	{
		result = [NSIndexPath indexPathWithIndex:0];
	}
	
    
	return result;
}

#pragma mark Contents

// Subclasses will do something useful
- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive; { }

- (void)writeContent:(SVHTMLContext *)context recursively:(BOOL)recursive;
{
	if ([self title])
	{
		[context writeCharacters:[self title]];
		[context startNewline];
	}
}

#pragma mark Thumbnail

- (BOOL)hasThumbnail;
{
    return ([self imageRepresentation] != nil);
}

- (CGFloat)thumbnailAspectRatio;
{
    CGFloat result = 1.0f;
    
    if ([[self thumbnailType] integerValue] == SVThumbnailTypeCustom)
    {
        CGSize size = IMBImageItemGetSize((id <IMBImageItem>)[[self customThumbnail] media]);
        result = size.width / size.height;
    }
    
    return result;
}

@dynamic thumbnailType;
@dynamic customThumbnail;

- (void)writeThumbnailPlaceholder:(SVHTMLContext *)context width:(NSUInteger)width height:(NSUInteger) height;
{
    // Fallback to placeholder <DIV>
    [(SVHTMLContext *)context pushAttribute:@"style" value:[NSString stringWithFormat:
                                                            @"width:%upx; height:%upx;",
                                                            width,
                                                            height]];
    [context startElement:@"div"];
    [context endElement];
    
}

- (BOOL)writeThumbnail:(SVHTMLContext *)context
                 width:(NSUInteger)width
                height:(NSUInteger)height
            attributes:(NSDictionary *)attributes  // e.g. custom CSS class
               options:(SVPageImageRepresentationOptions)options;
{
    [context addDependencyOnObject:self keyPath:@"thumbnailType"];
    
    
    // Write placeholder if there's no built-in image
    
    
    if (options & SVPageImageRepresentationLink)
    {
        [context pushClassName:@"imageLink"];
        [context startAnchorElementWithPage:self];
    }
    
    if (attributes) [context pushAttributes:attributes];
    BOOL result = [self writeImageRepresentation:context
                                            type:[[self thumbnailType] intValue]
                                           width:width
                                          height:height
                                         options:options];
    
    if (options & SVPageImageRepresentationLink) [context endElement];
    
    return result;
}

- (BOOL)writeImageRepresentation:(SVHTMLContext *)context
                            type:(SVThumbnailType)type
                           width:(NSUInteger)width
                          height:(NSUInteger)height
                         options:(SVPageImageRepresentationOptions)options;
{
    NSURL *url = [self addImageRepresentationToContext:context
                                                  type:type
                                                 width:width
                                                height:height
                                               options:options
                              pushSizeToCurrentElement:YES];
    
    if (url)
    {
        [context writeImageWithSrc:[context relativeStringFromURL:url]
                               alt:@""
                             width:nil
                            height:nil];
    }
    else
    {
        [self writeThumbnailPlaceholder:context width:width height:height];
    }

    return url != nil;
}

- (NSURL *)addImageRepresentationToContext:(SVHTMLContext *)context
                                      type:(SVThumbnailType)type
                                     width:(NSUInteger)width
                                    height:(NSUInteger)height
                                   options:(SVPageImageRepresentationOptions)options
                  pushSizeToCurrentElement:(BOOL)push;
{
    if (type == SVThumbnailTypeCustom && [self customThumbnail])
    {
		NSURL *result = [context addThumbnailMedia:[[self customThumbnail] media]
                                             width:width
                                            height:height
                                              type:nil
                                     scalingSuffix:nil
                                           options:options
                          pushSizeToCurrentElement:push];

        return result;
    }
    
    return nil;
}

- (id)imageRepresentation;
{
    id result = nil;
    
    if ([[self thumbnailType] integerValue] == SVThumbnailTypeCustom)
    {
        result = [[[self customThumbnail] media] imageRepresentation];
    }
    
    return result;
}

- (NSString *)imageRepresentationType;
{
    id result = nil;
    
    if ([[self thumbnailType] integerValue] == SVThumbnailTypeCustom)
    {
        result = [[[self customThumbnail] media] imageRepresentationType];
    }
    
    return result;
}

#pragma mark Summary

@dynamic customSummaryHTML;

- (void)writeRSSFeedItemDescription { }

- (BOOL)writeContent:(id <SVPlugInContext>)context
			  plugIn:(SVPlugIn *)plugIn
			 options:(SVPageWritingOptions)options;
{
    return [self writeContent:context truncation:0 plugIn:plugIn options:options];
}

- (BOOL)writeContent:(SVHTMLContext *)context
		  truncation:(NSUInteger)maxCount
			  plugIn:(SVPlugIn *)plugIn
			 options:(SVPageWritingOptions)options;
{
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setEditable:YES];
    [textBlock setRichText:YES];
    [textBlock setFieldEditor:NO];
    [textBlock setImportsGraphics:NO];
    
    [textBlock setHTMLSourceObject:self];
    [textBlock setHTMLSourceKeyPath:@"customSummaryHTML"];
    
    [textBlock writeHTML:context];
    [textBlock release];
    
    return NO;
}

#pragma mark Comments

// This will be a private API for use by General index
- (void)writeComments:(SVHTMLContext *)context; { }

#pragma mark UI

- (BOOL)isCollection { return NO; }
- (KTCodeInjection *)codeInjection; { return nil; }

#pragma mark Inspection

- (id)valueForUndefinedKey:(NSString *)key
{
    return ([self usesExtensiblePropertiesForUndefinedKey:key] ?
            [super valueForUndefinedKey:key] :
            NSNotApplicableMarker);
}

#pragma mark SVPage

- (NSArray *)childPages; { return [self sortedChildren]; }

- (id <NSFastEnumeration>)automaticRearrangementKeyPaths;
{
    static NSSet *result;
    if (!result)
    {
        result = [[NSSet alloc] initWithObjects:
                  @"childItems",
                  @"childIndex",
                  @"creationDate",
                  @"modificationDate",
                  @"title",
                  @"includeInSiteMap", nil];
    }
    
    return result;
}

- (NSArray *)archivePages; { return nil; }

- (SVLink *)link;
{
    return [SVLink linkWithSiteItem:self
                    openInNewWindow:[[self openInNewWindow] boolValue]];
}

- (BOOL)hasFeed; { return NO; }

- (BOOL)shouldIncludeInIndexes;
{
    BOOL result = ([[self includeInIndex] boolValue] && 
                   ([self datePublished] || ![self isDraftOrHasDraftAncestor]));
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingShouldIncludeInIndexes;
{
    return [NSSet setWithObjects:@"includeInIndex", @"datePublished", @"isDraft", nil];
}

- (BOOL)shouldIncludeInSiteMaps;
{
    BOOL result = ([[self includeInSiteMap] boolValue] && 
                   ([self datePublished] || ![self isDraftOrHasDraftAncestor]));
    return result;
}

- (NSString *)language { return nil; }

#pragma mark Core Data

+ (NSString *)entityName { return @"SiteItem"; }

/*	Picks out all the pages correspoding to self's entity
 */
+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC
{
	NSArray *result = [MOC fetchAllObjectsForEntityForName:[self entityName] error:NULL];
	return result;
}

/*	As above, but uses a predicate to narrow down to a particular ID
 */
+ (id)pageWithUniqueID:(NSString *)ID inManagedObjectContext:(NSManagedObjectContext *)MOC
{
	id result = [MOC objectWithUniqueID:ID entityName:[self entityName]];
	return result;
}

#pragma mark Serialization

- (void)awakeFromPropertyList:(id)propertyList parentItem:(SVSiteItem *)parent;
{
    [self awakeFromPropertyList:propertyList];
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;
{
    if ([key isEqualToString:@"uniqueID"])
    {
        // Is this ID free to use? #103155
        SVSiteItem *existingItem = [SVSiteItem pageWithUniqueID:serializedValue
                                         inManagedObjectContext:[self managedObjectContext]];
        if (existingItem) return;
    }
    
    [super setSerializedValue:serializedValue forKey:key];
}

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList
                            delegate:(id <SVPageSerializationDelegate>)delegate;
{
    // KTPage overrides this method to make use of the delegate
    
    [self populateSerializedProperties:propertyList];
}

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    [propertyList setObject:[[self entity] name] forKey:@"entity"];
}

@end
