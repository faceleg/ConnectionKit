//
//  KTPage+Paths.m
//  Marvel
//
//  Created by Mike on 05/12/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Provides access to various paths and URLs describing how to get to the page.
//	All methods have 1 of 3 prefixes:
//		published	- For accessing the published page via HTTP
//		upload		- When accessing the site for publishing via FTP, SFTP etc.
//		preview		- For previewing the page within the Sandvox UI


#import "KTPage+Paths.h"

#import "Debug.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTMaster.h"
#import "SVWebEditingURL.h"

#import "NSString+KTExtensions.h"

#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"

#import "KSPathUtilities.h"
#import "KSURLUtilities.h"


@interface KTPage (PathsPrivate)
- (NSString *)indexFilename;

- (NSString *)URLStringRelativeToParentPageAsCollection:(BOOL)collection;

- (NSString *)pathRelativeToParentWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
@end


#pragma mark -


@implementation KTPage (Paths)

#pragma mark -
#pragma mark File Name

- (NSString *)filename;
{
    NSString *result = [self fileName];
    if (![self isCollection])
    {
        result = [result stringByAppendingPathExtension:[self pathExtension]];
    }
    
    return result;
}

- (void)setFilename:(NSString *)filename;
{
    [self setFileName:[filename stringByDeletingPathExtension]];
    // Ignore path extension for now
}

/*	First we have a simple accessor pair for the file name. This does NOT include the extension.
 */
@dynamic fileName;
- (void)setFileName:(NSString *)fileName
{
	[self setWrappedValue:fileName forKey:@"fileName"];
	if (![self isRootPage]) [self recursivelyInvalidateURL:YES];	// For collections this affects all children
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

- (NSString *)preferredFilename;
{
    // To begin, this is based on the title. But once customised or published, filename should become stuck
    if ([self datePublished] || ![self shouldUpdateFileNameWhenTitleChanges])
    {
        return [[self fileName] stringByAppendingPathExtension:[self pathExtension]];
    }
    else
    {
        NSString *result = [[self title] suggestedLegalizedWebPublishingFileName];
        if (!result || [result isEqualToString:@""])
        {
            result = [self uniqueID];
        }
        
        if (![self isCollection]) result = [result stringByAppendingPathExtension:[self pathExtension]];
        
        return result;
    }
}

- (BOOL)isFilenameAvailable:(NSString *)filename forItem:(SVSiteItem *)item;
{
    OBPRECONDITION([self isCollection]);
    
    for (SVSiteItem *anItem in [self childItems])
    {
        if (anItem != item) // ignore the item itself if already part of collection
        {
            if ([[anItem filename] isEqualToStringCaseInsensitive:filename])
            {
                return NO;
            }
        }
    }
    
    return YES;
}

#pragma mark Path Extension


+ (NSSet *)keyPathsForValuesAffectingPathExtension
{
    return [NSSet setWithObjects:@"customFileExtension", @"defaultFileExtension", nil];
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

- (NSString *)defaultIndexAndPathExtension
{
	NSString *result = [[NSUserDefaults standardUserDefaults] objectForKey:@"fileExtension"];
	
	if (!result || [result isEqualToString:@""])
	{
		result = @"html";
	}
	
	if (result)
	{
		NSString *indexFileName = [[[self site] hostProperties] valueForKey:@"htmlIndexBaseName"];
		result = [indexFileName stringByAppendingPathExtension:result];
	}
	
	return result;
}

/*	If set, returns the custom file extension. Otherwise, takes the value from the defaults
 */
- (NSString *)pathExtension
{
	NSString *result = [self customPathExtension];
	
	if (!result) result = [self defaultPathExtension];
	
    OBPOSTCONDITION(result);
    return result;
}
- (void) setPathExtension:(NSString *)extension
{
	[self setCustomPathExtension:extension];
}


- (NSString *)indexAndPathExtension
{
	NSString *result = [self customIndexAndPathExtension];
	if (!result)
	{
		result = [self defaultIndexAndPathExtension];
	}
	return result;
}
- (void) setIndexAndPathExtension:(NSString *)newIndex
{
	[self setCustomIndexAndPathExtension:newIndex];
}




/*	All custom file extensions available for the receiver. Mainly used for bindings.
 */
- (NSArray *)availablePathExtensions
{
	NSArray *result = [NSArray arrayWithObjects:@"html", @"htm", @"php", @"shtml", @"asp", @"aspx", @"cfm", @"cgi", @"jsp", nil];
	return result;
}

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
		NSString *path = [self URLStringRelativeToParentPageAsCollection:[self isCollection]];
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
		result = [[self URLAsCollection:[self isCollection]]
                  URLWithWebEditorPreviewPath:[self previewPath]];
        
		[self setPrimitiveValue:result forKey:@"URL"];
	}
	
	return result;
}

/*	The index.html file is not included in collection paths unless the user defaults say to.
 *	If you ask this of the home page, will either return an empty string or index.html.
 */
- (NSString *)URLStringRelativeToParentPageAsCollection:(BOOL)collection;
{
	KTCollectionPathStyle collectionPathStyle = KTCollectionNotEvenACollection;
    if (collection)
    {
        collectionPathStyle = KTCollectionHTMLDirectoryPath;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PathsWithIndexPages"]) {
            collectionPathStyle = KTCollectionIndexFilePath;
        }
    }
	
	NSString *result = [self pathRelativeToParentWithCollectionPathStyle:collectionPathStyle];
	return result;
}

#pragma mark -
#pragma mark Uploading

/*	The path the page will be uploaded to when publishing/exporting.
 *	This path is RELATIVE to the base directory of the site so that it
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
#pragma mark Support

/*	Does the hard graft for -publishedPathRelativeToParent.
 *	Should NOT be called externally, PRIVATE method only.
 */
- (NSString *)pathRelativeToParentWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle
{
	NSString *result = @"";
	if (![self isRoot])
	{
		result = [self filename];
	}
	
	if (collectionPathStyle != KTCollectionNotEvenACollection)
	{
		if (collectionPathStyle == KTCollectionIndexFilePath)
		{
			result = [result stringByAppendingPathComponent:[self indexFilename]];
		}
		else if (collectionPathStyle == KTCollectionHTMLDirectoryPath)
		{
			result = [result ks_URLDirectoryPath];
		}
	}
	
	return result;
}

/*	Does the hard graft for -publishedPathRelativeToSite and -uploadPathRelativeToSite.
 *	Should not generally be called outside of KTPage methods.
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
			result = [result ks_URLDirectoryPath];
		}
	}
	
	return result;
}

#pragma mark Custom

- (NSURL *)URLAsCollection:(BOOL)collection;
{
    NSURL *result = nil;
	
    if ([self isRoot])
    {
        // Root is a sepcial case where we just supply the site URL
        result = [[[self site] hostProperties] siteURL];
        
        // The siteURL may not include index.html, so we have to guarantee it here
        if (!result || [[NSUserDefaults standardUserDefaults] boolForKey:@"PathsWithIndexPages"])
        {
            result = [NSURL URLWithString:[self indexFilename] relativeToURL:result];
        }
    }
    else
    {
        // For normal pages, figure out the path relative to parent and resolve it
        NSURL *baseURL = [[self parentPage] URL];
        if (baseURL)
        {
            NSString *path = [self URLStringRelativeToParentPageAsCollection:collection];
            if (path)
            {
                result = [NSURL URLWithString:path relativeToURL:baseURL];
            }
        }
    }
	
	return result;
}

@end
