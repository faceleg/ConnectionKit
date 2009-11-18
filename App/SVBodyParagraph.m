// 
//  SVParagraph.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyParagraph.h"

#import "SVPlugInContentObject.h"

@implementation SVBodyParagraph 

@dynamic tagName;
@dynamic archivedInnerHTMLString;
@dynamic inlineContentObjects;

- (NSString *)HTMLString;
{
    NSString *result = [NSString stringWithFormat:
                        @"<%@>%@</>",
                        [self tagName],
                        [self archivedInnerHTMLString]];
    
    return result;
}

@end
