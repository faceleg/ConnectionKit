//
//  KTAbstractPage+Paths.m
//  Marvel
//
//  Created by Mike on 05/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//	Provides access to various paths and URLs describing how to get to the page.
//	All methods have 1 of 3 prefixes:
//		published	- For accessing the published page via HTTP
//		upload		- When accessing the site for publishing via FTP, SFTP etc.
//		preview		- For previewing the page within the Sandvox UI

#import "KTAbstractPage.h"
#import "KTPage.h"

#import "Debug.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTMaster.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"


@interface KTAbstractPage (PathsPrivate)
- (NSString *)indexFilename;

- (NSURL *)URL_uncached;
- (NSString *)pathRelativeToParent;

- (NSString *)pathRelativeToParentWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
@end


#pragma mark -


@implementation KTAbstractPage (Paths)

#pragma mark -
#pragma mark File Name

/*	First we have a simple accessor pair for the file name. This does NOT include the extension.
 */
- (NSString *)fileName { return [self wrappedValueForKey:@"fileName"]; }

- (void)setFileName:(NSString *)fileName
{
	[self setWrappedValue:fileName forKey:@"fileName"];
	[self recursivelyInvalidateURL:YES];	// For collections this affects all children
}

/*  Legalize the filename
 */
- (BOOL)validateFileName:(NSString **)outFileName error:(NSError **)error
{
    if (![self isRoot])
    {
        NSString *fileName = *outFileName;
        if (!fileName || ![NSURL URLWithString:fileName])
        {
            NSString *legalizedFileName = [fileName legalizedWebPublishingFileName];
            if (!legalizedFileName || [legalizedFileName isEqualToString:@""])
            {
                legalizedFileName = [self uniqueID];
            }
            
            *outFileName = legalizedFileName;
        }
    }
    
    return YES;
}

/*	Looks at sibling pages and the page title to determine the best possible filename.
 *	Guaranteed to return something unique.
 */
- (NSString *)suggestedFileName
{
	// The home page's title isn't settable, so keep it constant
	if ([self isRoot]) return nil;
	
	
	// Get the preferred filename by converting to lowercase, spaces to _, & removing everything else
    NSString *result = [[self title] legalizedWebPublishingFileName];
    if (!result || [result isEqualToString:@""])
    {
        result = [self uniqueID];
    }
    
	NSString *baseFileName = result;
	int suffixCount = 2;
	
    
	// Build a list of the file names already taken
	NSSet *siblingFileNames = [[[self parentPage] childItems] valueForKey:@"fileName"];
	NSSet *archiveFileNames = [[self parentPage] valueForKeyPath:@"archivePages.fileName"];
	NSMutableSet *unavailableFileNames = [NSMutableSet setWithCapacity:([siblingFileNames count] + [archiveFileNames count])];
	[unavailableFileNames unionSet:siblingFileNames];
	[unavailableFileNames unionSet:archiveFileNames];
	[unavailableFileNames removeObjectIgnoringNil:[self fileName]];
	
    
	// Now munge it to make it unique.  Keep adding a number until we find an open slot.
	while ([unavailableFileNames containsObject:result])
	{
		result = [baseFileName stringByAppendingFormat:@"_%d", suffixCount++];
	}
	
	OBPOSTCONDITION(result);
	
	return result;
}

#pragma mark -
#pragma mark File Extension

/*	If set, returns the custom file extension. Otherwise, takes the value from the defaults
 */
- (NSString *)pathExtension
{
	return [self defaultPathExtension];
}

/*	The value -fileExtension should return if there is no custom extensions set.
 *	Mainly used for bindings.
 */
- (NSString *)defaultPathExtension
{
	NSString *result = [[NSUserDefaults standardUserDefaults] objectForKey:@"fileExtension"];
	
	if (!result || [result isEqualToString:@""])
	{
		result = @"html";
	}
	
	return result;
}

/*	All custom file extensions available for the receiver. Mainly used for bindings.
 */
- (NSArray *)availablePathExtensions
{
	NSArray *result = [NSArray arrayWithObjects:@"html", @"htm", @"php", @"shtml", @"asp", nil];
	return result;
}

#pragma mark -
#pragma mark Filenames & Extensions

/*	The correct filename for the index.html file, taking into account user defaults and any custom settings
 *	If not a collection, returns nil.
 */
- (NSString *)indexFilename
{
	NSString *result = nil;
	
	if ([self isCollection])
	{
		NSString *indexFileName = [[[self site] hostProperties] valueForKey:@"htmlIndexBaseName"];
		OBASSERT([self pathExtension]);
		result = [indexFileName stringByAppendingPathExtension:[self pathExtension]];
	}
	
	return result;
}

- (NSString *)indexFileName
{
	NSString *result = nil;
    
    KTSite *site = [self site];
	if (site)
	{
        result = [[site hostProperties] valueForKey:@"htmlIndexBaseName"];
        OBASSERT(result);
    }
    
	return result;
}

- (NSString *)archivesFilename
{
	NSString *result = nil;
	
	if ([self isCollection])
	{
		NSString *archivesFileName = [[[self site] hostProperties] valueForKey:@"archivesBaseName"];
		OBASSERT([self pathExtension]);
		result = [archivesFileName stringByAppendingPathExtension:[self pathExtension]];
	}
	
	return result;
}

/*	Used for bindings to pull together a selection of different filenames/extensions available.
 */
- (NSArray *)availableIndexFilenames
{
	NSString *indexFileName = [self indexFileName];
    if (indexFileName)
    {
        NSArray *availableExtensions = [self availablePathExtensions];
        NSString *anExtension;
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[availableExtensions count]];
        
        for (anExtension in availableExtensions)
        {
            OBASSERT(anExtension);
            NSString *aFilename = [indexFileName stringByAppendingPathExtension:anExtension];
            [result addObject:aFilename];
        }
        
        return result;
    }
    else
    {
        return [NSArray array];
    }
}

#pragma mark -
#pragma mark URL


////////// Trying to bind the URL field in the page details.  Actually I want the URL string
// of the parent, so that we can append the title to this.

- (NSURL *)_baseExampleURL
{
	NSURL *result = nil;
	if ([self isRoot])
	{
		result = [super _baseExampleURL];
	}
	else
	{
		// For normal pages, figure out the path relative to parent and resolve it
		NSString *path = [self pathRelativeToParent];
		if (path)
		{
			result = [NSURL URLWithString:path relativeToURL:[[self parentPage] _baseExampleURL]];
		}
	}
	return result;
}

- (BOOL) canPreview
{
	return (nil != [self URL]);
}

- (NSString *)baseExampleURLString
{
	NSURL *resultURL = nil;
	if ([self isRoot])
    {
        resultURL = [self _baseExampleURL];
    }
    else
    {
        resultURL = [[self parentPage] _baseExampleURL];
    }

    NSString *result = [resultURL absoluteString];
	return result;
}
+ (NSSet *)keyPathsForValuesAffectingBaseExampleURLString
{
    return [NSSet setWithObject:@"URL"];
}
/////////

- (NSURL *)URL
{
	NSURL *result = [self wrappedValueForKey:@"URL"];
	
	if (!result)
	{
		result = [self URL_uncached];
		[self setPrimitiveValue:result forKey:@"URL"];
	}
	
	return result;
}

- (NSURL *)URL_uncached
{
	NSURL *result = nil;
	
    if ([self isRoot])
    {
        // Root is a sepcial case where we just supply the site URL
        result = [[[self site] hostProperties] siteURL];
        
        // The siteURL may not include index.html, so we have to guarantee it here
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PathsWithIndexPages"])
        {
            result = [NSURL URLWithString:[self indexFilename] relativeToURL:result];
        }
    }
    else
    {
        // For normal pages, figure out the path relative to parent and resolve it
        NSString *path = [self pathRelativeToParent];
        if (path)
        {
            result = [NSURL URLWithString:path relativeToURL:[[self parentPage] URL]];
        }
    }
	
	return result;
}


/*	Sends out a KVO notification that the page's URL has changed. Upon the next request for the URL it will be
 *	regenerated and cached.
 *	KTAbstractPage does not support children, so it is up to KTPage to implement the recursive portion.
 *
 *	If the URL is invalid, it can be assumed that the site structure must have changed, so we also post a notification.
 */
- (void)recursivelyInvalidateURL:(BOOL)recursive
{
	[self willChangeValueForKey:@"URL"];
	[self setPrimitiveValue:nil forKey:@"URL"];
	
	[self didChangeValueForKey:@"URL"];
}


/*	The index.html file is not included in collection paths unless the user defaults say to.
 *	If you ask this of the home page, will either return an empty string or index.html.
 */
- (NSString *)pathRelativeToParent
{
	int collectionPathStyle = KTCollectionHTMLDirectoryPath;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PathsWithIndexPages"]) {
		collectionPathStyle = KTCollectionIndexFilePath;
	}
	
	NSString *result = [self pathRelativeToParentWithCollectionPathStyle:collectionPathStyle];
	return result;
}

#pragma mark -
#pragma mark Uploading

/*	The path the page will be uploaded to when publishing/exporting.
 *	This path is RELATIVE to the base diretory of the site so that it
 *	works for both publishing and exporting.
 *
 *	Some typical examples:
 *		index.html			-	Home Page
 *		text.html			-	Text page
 *		photos/index.html	-	Photo album
 *		photos/photo1.html	-	Photo page in album
 */
- (NSString *)uploadPath
{
	NSString *result = [self pathRelativeToSiteWithCollectionPathStyle:KTCollectionIndexFilePath];
	return result;
}

#pragma mark -
#pragma mark Preview

- (NSString *)previewPath
{
	NSString *result = [NSString stringWithFormat:@"%@%@", kKTPageIDDesignator, [self uniqueID]];
	return result;
}

#pragma mark -
#pragma mark Support

/*	Does the hard graft for -publishedPathRelativeToParent.
 *	Should NOT be called externally, PRIVATE method only.
 */
- (NSString *)pathRelativeToParentWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle
{
	NSString *result = @"";
	if (![self isRoot])
	{
		result = [self fileName];
	}
	
	if ([self isCollection])
	{
		if (collectionPathStyle == KTCollectionIndexFilePath)
		{
			result = [result stringByAppendingPathComponent:[self indexFilename]];
		}
		else if (collectionPathStyle == KTCollectionHTMLDirectoryPath)
		{
			result = [result HTMLDirectoryPath];
		}
	}
	else
	{
		OBASSERT([self pathExtension]);
        if (![result isEqualToString:@""])  // appending to an empty string logs a warning. case 40704
        {
            result = [result stringByAppendingPathExtension:[self pathExtension]];
        }
	}
	
	return result;
}

/*	Does the hard graft for -publishedPathRelativeToSite and -uploadPathRelativeToSite.
 *	Should not generally be called outside of KTAbstractPage methods.
 */
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle
{
	NSString *parentPath = @"";
	if (![self isRoot])
	{
		parentPath = [[self parentPage] pathRelativeToSiteWithCollectionPathStyle:KTCollectionDirectoryPath];
	}
	
	NSString *relativePath = [self pathRelativeToParentWithCollectionPathStyle:collectionPathStyle];
	NSString *result = nil;
	
	if (relativePath)
	{
		result = [parentPath stringByAppendingPathComponent:relativePath];
		
		// NSString doesn't handle KTCollectionHTMLDirectoryPath-style strings; we must fix them manually
		if (collectionPathStyle == KTCollectionHTMLDirectoryPath && [self isCollection])
		{
			result = [result HTMLDirectoryPath];
		}
	}
	
	return result;
}

@end
