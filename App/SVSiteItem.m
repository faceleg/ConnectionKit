// 
//  SVSiteItem.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSiteItem.h"

#import "KTPage.h"
#import "SVWebEditorViewController.h"


@implementation SVSiteItem 

#pragma mark Title

@dynamic title;

#pragma mark Dates

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // attributes
	NSDate *now = [NSDate date];
	[self setPrimitiveValue:now forKey:@"creationDate"];
	[self setPrimitiveValue:now forKey:@"lastModificationDate"];
}

@dynamic creationDate;
@dynamic lastModificationDate;

#pragma mark Drafts and Indexes

@dynamic isDraft;
- (void)setIsDraft:(NSNumber *)flag;
{
	[self setWrappedValue:flag forKey:@"isDraft"];
	
	
	// And the index
	[[self parentPage] invalidatePagesInIndexCache];
}

- (BOOL)pageOrParentDraft
{
	BOOL result = [[self isDraft] boolValue];
	if (!result && [self parentPage] != nil)
	{
		result = [[self parentPage] pageOrParentDraft];
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
		NSString *serverPath = [self publishedPath];
		
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		if (nil == serverPath && [self pageOrParentDraft])
		{
			result = YES;	// DON'T include if if hasn't been published before, and if it's draft
		}
	}
	return result;
}

- (BOOL)includeInIndex { return [self wrappedBoolForKey:@"includeInIndex"]; }

- (void)setIncludeInIndex:(BOOL)flag
{
	[self setWrappedBool:flag forKey:@"includeInIndex"];
	
	
	// We must update the parent's list of pages
	[[self parentPage] invalidatePagesInIndexCache];
}

#pragma mark URL

- (NSURL *)URL { return nil; }
- (NSString *)fileName { return nil; }

#pragma mark Editing

- (SVExternalLink *)externalLinkRepresentation { return nil; }	// used to determine if it's an external link, for page details.

- (KTPage *)pageRepresentation { return nil; }

#pragma mark Publishing

@dynamic publishedPath;
- (void)setPublishedPath:(NSString *)path
{
	[self setWrappedValue:path forKey:@"publishedPath"];
	
	// Our status in the index could depend on this key
	[[self parentPage] invalidatePagesInIndexCache];
}

// Derived accessor to determine if page should be included in the index AND it has been published or not draft
// In other words, if it's a draft, don't include -- but if it's a draft that is already published, keep it

- (BOOL)includeInIndexAndPublish
{
	BOOL result = [self includeInIndex];
	if (result)
	{
		// thinks it should be in index, so see if maybe we shouldn't publish it.  Faster to check serverPath first.
		NSString *serverPath = [self publishedPath];
		if (nil == serverPath && [[self isDraft] boolValue])		// Ask if page ITSELF is a draft.  Do not inherit here.
		{
			result = NO;	// DON'T include if if hasn't been published before, and if it's draft
		}
	}
	return result;
}

#pragma mark Tree

- (NSSet *)childItems { return nil; }

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

- (BOOL)isDescendantOfCollection:(KTPage *)aPotentialAncestor;
{
	if (aPotentialAncestor == self) return YES;
    
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

#pragma mark UI

- (BOOL)isCollection { return NO; }
- (KTMediaContainer *)customSiteOutlineIcon { return nil; }
- (KTCodeInjection *)codeInjection; { return nil; }

- (Class <SVWebContentViewController>)viewControllerClass
{
    return [SVWebEditorViewController class];
}
    
#pragma mark Inspection

- (id)valueForUndefinedKey:(NSString *)key
{
    return NSNotApplicableMarker;
}

@end
