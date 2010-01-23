// 
//  SVTitleBox.m
//  Sandvox
//
//  Created by Mike on 07/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTitleBox.h"
#import "SVWebEditorTextFieldController.h"

#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"


@implementation SVTitleBox 

#pragma mark Content

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

@dynamic hidden;

- (Class)DOMControllerClass;
{
    return [SVWebEditorTextFieldController class];
}

@end
