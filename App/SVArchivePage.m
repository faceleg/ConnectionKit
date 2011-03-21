//
//  SVArchivePage.m
//  Sandvox
//
//  Created by Mike on 20/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVArchivePage.h"

#import "KTPage+Paths.h"
#import "NSObject+Karelia.h"
#import "SVGraphicFactory.h"
#import "SVHTMLTemplateParser.h"
#import "SVIndexPlugIn.h"
#import "SVIndexPlugIn.h"
#import "SVLink.h"
#import "SVPlugInGraphic.h"
#import "SVRichText.h"
#import "SVTextAttachment.h"


@implementation SVArchivePage

- (id)initWithPages:(NSArray *)pages;
{
    OBPRECONDITION([pages count]);
    
    [self init];
    
    _childPages = [pages copy];
    _collection = [[[pages lastObject] parentPage] retain];
    
    return self;
}

- (void)dealloc;
{
    [_childPages release];
    [_collection release];
    
    [super dealloc];
}

@synthesize collection = _collection;
- (id <SVPage>)parentPage; { return nil; }  // could return -collection in future

- (NSString *)identifier; { return nil; }

- (NSString *)title;
{
	// set up a formatter since descriptionWithCalendarFormat:timeZone:locale: may not match site locale
	static NSDateFormatter *sDateFormatter;
    if (!sDateFormatter)
    {
        sDateFormatter = [[NSDateFormatter alloc] init];
        [sDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [sDateFormatter setDateFormat:@"MMMM yyyy"]; // unicode pattern for @"%B %Y"
    }
    
	// find our locale from the site itself
	NSString *language = [self language];
    if (![language isEqualToString:[[sDateFormatter locale] localeIdentifier]])
    {
        NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:language] autorelease];
        [sDateFormatter setLocale:locale];
    }
	
	NSDate *date = [[[self childPages] lastObject] creationDate];
	NSString *result = [sDateFormatter stringFromDate:date];
	return result;
}

- (BOOL)showsTitle; { return YES; }

// Returns YES if truncated.

- (void)writeRSSFeedItemDescription { }

- (BOOL)writeSummary:(id <SVPlugInContext>)context includeLargeMedia:(BOOL)includeLargeMedia truncation:(NSUInteger)maxCount; { return NO; }

- (NSString *)language; { return [[self collection] language]; }

- (BOOL)isCollection; { return NO; }
- (NSArray *)childPages; { return _childPages; }
- (id <SVPage>)rootPage; { return [[self collection] rootPage]; }
- (id <NSFastEnumeration>)automaticRearrangementKeyPaths; { return nil; }

- (NSArray *)archivePages; { return nil; }

#pragma mark Timestamp

- (NSString *)timestampDescription; { return nil; }
- (NSDate *)creationDate; { return nil; }
- (NSDate *)modificationDate; { return nil; }
- (NSString *)timestampDescriptionWithDate:(NSDate *)date; { return nil; }

#pragma mark Being for the benefit of index pages controller

- (NSSet *)childItems; { return [NSSet setWithArray:[self childPages]]; }

- (NSArray *)childItemsSortDescriptors;
{
    // Always sort chronologically
    return [KTPage dateCreatedSortDescriptorsAscending:NO];
}

#pragma mark Location

- (NSURL *)URL;
{
    NSURL *result = [NSURL URLWithString:[@"archives/" stringByAppendingString:[self filename]]
                           relativeToURL:[[self collection] URL]];
    return result;
}

- (SVLink *)link;
{
    return [SVLink linkWithURLString:[[self URL] absoluteString]
                     openInNewWindow:NO];
}

- (NSURL *)feedURL { return nil; }

- (NSString *)uploadPath;
{
    NSString *directory = [[[self collection] uploadPath] stringByDeletingLastPathComponent];
    
    NSString *result = [directory stringByAppendingPathComponent:
                        [@"archives/" stringByAppendingString:[self filename]]];
    return result;
}

- (NSString *)filename;
{
    // Get the month formatted like "01_2008"
    static NSDateFormatter *sFormatter;
    if (!sFormatter)
    {
        sFormatter = [[NSDateFormatter alloc] init];
        [sFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [sFormatter setDateFormat:@"MM'-'yyyy'.html'"];
    }
    
    NSDate *date = [[[self childPages] lastObject] creationDate];
	NSString *result = [sFormatter stringFromDate:date];
    
    return result;
}

#pragma mark Other

- (BOOL)shouldIncludeInIndexes; { return NO; }
- (BOOL)shouldIncludeInSiteMaps; { return NO; }

- (BOOL)writeThumbnail:(id <SVPlugInContext>)context
              maxWidth:(NSUInteger)width
             maxHeight:(NSUInteger)height
        imageClassName:(NSString *)className
                dryRun:(BOOL)dryRun;
{
    return NO;
}

#pragma mark Article

- (void)writeHTML;
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
	// get this archive page's collection, and then look at what indexes it has if possible
	// With found one, make sure collection == plugIn.indexedCollection
	NSArray *attachments = [[self.collection article] orderedAttachments];
	SVIndexPlugIn *foundIndexPlugIn = nil;
	NSString *foundIndexPlugInIdentifier = nil;
	for (SVTextAttachment *attachment in attachments)
	{
		SVGraphic *graphic = [attachment graphic];
		if ([graphic respondsToSelector:@selector(plugIn)])
		{
			SVPlugInGraphic *pluginGraphic = (SVPlugInGraphic *)graphic;
			SVPlugIn *plugIn = [pluginGraphic plugIn];
			NSString *plugInIdentifier = [pluginGraphic plugInIdentifier];
			
			// Is it an index, but NOT  a collection archive :-)
			if ([plugIn isKindOfClass:[SVIndexPlugIn class]] && ![plugInIdentifier isEqualToString:@"sandvox.CollectionArchiveElement"])
			{
				foundIndexPlugIn = (SVIndexPlugIn *)plugIn;
				foundIndexPlugInIdentifier = plugInIdentifier;
				break;
			}
		}
	}
	
	// NSLog(@"I want to make a copy of this SVIndexPlugIn: %@", foundIndexPlugIn);
	NSString *identifier = foundIndexPlugIn ? foundIndexPlugInIdentifier : @"sandvox.GeneralIndex";
    
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:identifier];
    SVIndexPlugIn *plugIn = [[[factory plugInClass] alloc] init];
    
	if (foundIndexPlugIn)
	{
		for (NSString *aKey in [[plugIn class] plugInKeys])
		{
			id sourceValue = [foundIndexPlugIn valueForKey:aKey];
			// DJW((@"Key: %@ Value: %@ [%@]", aKey, sourceValue, [sourceValue class]));
			[plugIn setSerializedValue:sourceValue forKey:aKey];
		}
	}
	else	// don't have a source index; make our own settings
	{
		[plugIn setBool:YES forKey:@"hyperlinkTitles"];
		[plugIn setBool:YES forKey:@"showEntries"];
		[plugIn setBool:YES forKey:@"showTitles"];
		[plugIn setBool:YES forKey:@"showTimestamps"];
		[plugIn setInteger:275 forKey:@"indexLayoutType"]; // kLayoutArticlesAndMedia
	}
	
    [plugIn setIndexedCollection:self];	// Obviously this has to change from what got copied over
    
    [plugIn writeHTML:context];
    
    [plugIn release];		// don't need this temporary one any more
}

@end
