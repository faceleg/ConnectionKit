// 
//  SVTextField.m
//  Sandvox
//
//  Created by Mike on 07/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextField.h"


#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"


@implementation SVTextField 

@dynamic textHTMLString;

- (NSString *)text	// get title, but without attributes
{
	NSString *html = [self textHTMLString];
	NSString *result = [html stringByConvertingHTMLToPlainText];
	return result;
}

- (void)setText:(NSString *)value
{
	[self setTextHTMLString:[value stringByEscapingHTMLEntities]];
}

+ (NSSet *)keyPathsForValuesAffectingText
{
    return [NSSet setWithObject:@"textHTMLString"];
}

@end
