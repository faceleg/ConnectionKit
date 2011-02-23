//
//  TweetButtonInspector.m
//  TweetButtonElement
//
//  Created by Terrence Talbot on 2/21/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import "TweetButtonInspector.h"


@implementation TweetButtonInspector

- (void)awakeFromNib
{
    [self addObserver:self 
           forKeyPath:@"inspectedPages"
              options:0 
              context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [[self inspectedPages] addObserver:self
                    toObjectsAtIndexes:[NSIndexSet indexSetWithIndex:0] 
                            forKeyPath:@"title" 
                               options:0 
                               context:NULL];

    id<SVPage> inspectedPage = [[self inspectedPages] objectAtIndex:0];
    NSString *title = [inspectedPage title];
    [[[self tweetTextField] cell] setPlaceholderString:title];
}

- (void)dealloc
{
    [[self inspectedPages] removeObserver:self 
                     fromObjectsAtIndexes:[NSIndexSet indexSetWithIndex:0] 
                               forKeyPath:@"title"];
    [self removeObserver:self forKeyPath:@"inspectedPages"];
    [super dealloc];
}


@synthesize tweetTextField = _tweetTextField;
@end
