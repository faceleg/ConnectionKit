//
//  VictualPlugIn.h
//  VictualElement
//
//  Created by Terrence Talbot on 1/5/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Sandvox.h>


@interface VictualPlugIn : SVPlugIn
{
    NSURL *_feedURL;
    NSUInteger _limit;
    NSString *_titleTag;
    NSString *_errorMessage;
    NSString *_googleAPIKey;
    BOOL _showContent;
    BOOL _showDate;
    BOOL _showError;
    BOOL _showHeader;
    BOOL _showSnippet;
}

@property(nonatomic, copy) NSURL *feedURL;
@property(nonatomic) NSUInteger limit;
@property(nonatomic) BOOL showSnippet;

// not currently exposed in UI
@property(nonatomic) BOOL showContent;
@property(nonatomic) BOOL showDate;
@property(nonatomic) BOOL showError;
@property(nonatomic) BOOL showHeader;
@property(nonatomic, copy) NSString *errorMessage;
@property(nonatomic, copy) NSString *googleAPIKey;
@property(nonatomic, copy) NSString *titleTag;

@end
