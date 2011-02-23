//
//  TweetButtonInspector.m
//  TweetButtonElement
//
//  Created by Terrence Talbot on 2/21/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import "TweetButtonInspector.h"


@implementation TweetButtonInspector

- (NSString *)tweetPlaceholder
{
    return [self.inspectedPagesController valueForKeyPath:@"selection.title"];
}

- (void)bindTweetTextField
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [self tweetPlaceholder], NSNullPlaceholderBindingOption,
                             [NSNumber numberWithBool:YES], NSConditionallySetsEditableBindingOption,
                             nil];
    [self.tweetTextField bind:@"value"
                     toObject:self
                  withKeyPath:@"inspectedObjectsController.selection.tweetText"
                      options:options];
}

- (void)unbindTweetTextField
{
    [self.tweetTextField unbind:@"value"];
}

- (void)awakeFromNib
{
    [self.inspectedPagesController addObserver:self 
                                    forKeyPath:@"selection.title"
                                       options:0 
                                       context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( [keyPath isEqualToString:@"selection.title" ] )
    {
        [self unbindTweetTextField];
        [self bindTweetTextField];
    }
}

- (void)dealloc
{
    [self unbindTweetTextField];
    [self.inspectedPagesController removeObserver:self forKeyPath:@"selection.title"];
    self.inspectedPagesController = nil;
    self.tweetTextField = nil;
    [super dealloc];
}


@synthesize inspectedPagesController = _inspectedPagesController;
@synthesize tweetTextField = _tweetTextField;
@end
