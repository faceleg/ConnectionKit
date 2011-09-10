//
//  WEKWebViewEditing.m
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "WEKWebViewEditing.h"

#import "SVWebViewSelectionController.h"

#import "DOMRange+Karelia.h"
#import "NSString+Karelia.h"


#pragma mark -


@implementation WebView (WEKWebViewEditing)

#pragma mark Alignment

- (NSTextAlignment)wek_alignment;
{
    NSTextAlignment result = NSNaturalTextAlignment;
    
    DOMDocument *doc = [[self selectedFrame] DOMDocument];
    if ([[doc queryCommandValue:@"justifyleft"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSLeftTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifycenter"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSCenterTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifyright"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSRightTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifyfull"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSJustifiedTextAlignment;
    }
    
    return result;
}

@end


#pragma mark -


