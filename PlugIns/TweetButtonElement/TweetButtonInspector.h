//
//  TweetButtonInspector.h
//  TweetButtonElement
//
//  Created by Terrence Talbot on 2/21/11.
//  Copyright 2011 Terrence Talbot. All rights reserved.
//

#import <Sandvox.h>


@interface TweetButtonInspector : SVInspectorViewController
{
    NSTextField *_tweetTextField;
}

@property (nonatomic, retain) IBOutlet NSTextField *tweetTextField;

@end
