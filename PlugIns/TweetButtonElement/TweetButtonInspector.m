//
//  TweetButtonInspector.m
//  TweetButtonElement
//
//  Created by Terrence Talbot on 2/21/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import "TweetButtonInspector.h"


@implementation TweetButtonInspector

- (void)updatePlaceholder
{
    id<SVPage> inspectedPage = [[self inspectedPages] objectAtIndex:0];
    if ( inspectedPage )
    {
        NSString *title = [inspectedPage title];
        [[[self tweetTextField] cell] setPlaceholderString:title];
    }
}

- (void)awakeFromNib
{
    [self addObserver:self 
           forKeyPath:@"inspectedPages"
              options:0 
              context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( [keyPath isEqualToString:@"inspectedPages" ] )
    {
        [[self inspectedPages] addObserver:self
                        toObjectsAtIndexes:[NSIndexSet indexSetWithIndex:0] 
                                forKeyPath:@"title" 
                                   options:0 
                                   context:NULL];
        [self updatePlaceholder];
    }
    else if ( [keyPath isEqualToString:@"title"] )
    {
        [self updatePlaceholder];
    }
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
