// 
//  SVSiteItem.m
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSiteItem.h"

#import "KTPage.h"


@implementation SVSiteItem 

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

- (short)childIndex { return [self wrappedIntegerForKey:@"childIndex"]; }

- (void)setChildIndex:(short)index { [self setWrappedInteger:index forKey:@"childIndex"]; }

#pragma mark Site Outline

- (BOOL)isCollection { return NO; }
- (KTMediaContainer *)customSiteOutlineIcon { return nil; }

#pragma mark Inspection

- (id)valueForUndefinedKey:(NSString *)key
{
    return NSNotApplicableMarker;
}

@end
