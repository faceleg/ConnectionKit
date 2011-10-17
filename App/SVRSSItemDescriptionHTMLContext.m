//
//  SVRSSItemDescriptionHTMLContext.m
//  Sandvox
//
//  Created by Mike on 31/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVRSSItemDescriptionHTMLContext.h"


@implementation SVRSSItemDescriptionHTMLContext

- (void)startElement:(NSString *)tagName
{
    if ([tagName isEqualToString:@"noscript"] && _noScriptLevel == 0)
    {
        _noScriptLevel = [self openElementsCount] + 1;  // so defintiely can't be 0
    }
    else
    {
        if ([tagName isEqualToString:@"script"])
        {
            _writingScript = YES;
        }
        
        [super startElement:tagName];
    }
}

- (void)endElement;
{
    if (_noScriptLevel && [self openElementsCount] == _noScriptLevel - 1)
    {
        _noScriptLevel = 0;
    }
    else if (_writingScript && [[self topElement] isEqualToString:@"script"])
    {
        [super endElement];
        _writingScript = NO;
    }
    else
    {
        [super endElement];
    }
}

- (void)writeString:(NSString *)string;
{
    if (!_writingScript) [super writeString:string];
}

@end
