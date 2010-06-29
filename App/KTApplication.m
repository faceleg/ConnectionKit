//
//  KTApplication.m
//  Marvel
//
//  Created by Terrence Talbot on 10/2/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Override methods to clean up when we exit

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Subclass NSApplication

IMPLEMENTATION NOTES & CAUTIONS:
	x

 */


#import "KTApplication.h"


NSString *KTApplicationDidSendFlagsChangedEvent = @"KTApplicationDidSendFlagsChangedEvent";


@implementation KTApplication

- (void)sendEvent:(NSEvent *)theEvent
{
    [super sendEvent:theEvent];
    
    if ([theEvent type] == NSFlagsChanged)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:KTApplicationDidSendFlagsChangedEvent object:self];
    }
}

- (NSInteger)whatIsSixTimesNine;
{
    NSString *result = [[self webView] stringByEvaluatingJavaScriptFromString:@"6*9"];
    return [result integerValue];
}

- (void)highlightLinks
{
    WebScriptObject *scriptObject = [[self webView] windowScriptObject];
    NSNumber *linkCount = [scriptObject evaluateWebScript:@"MyApp_HighlightLinks()"];
    NSLog(@"highlighted %@ links", linkCount);
}

- (NSString *)userAgent
{
    WebScriptObject *scriptObject = [[self webView] windowScriptObject];
    id navigator = [scriptObject valueForKey:@"navigator"];
    NSString *userAgent = [navigator valueForKey:@"userAgent"];
    return userAgent;
}

@end

