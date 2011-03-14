//
//  SVTitleBox.h
//  Sandvox
//
//  Created by Mike on 07/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//


#import "SVContentObject.h"


@interface SVTitleBox : SVContentObject  

@property(nonatomic, copy) NSString *textHTMLString;
@property(nonatomic, copy) NSString *text;

@property(nonatomic, copy) NSNumber *hidden;    // BOOL, required
@property(nonatomic, readonly) NSTextAlignment alignment;

- (NSString *)graphicalTextCode:(SVHTMLContext *)context;

@end


#pragma mark -


@interface SVSiteTitle : SVTitleBox
@end


#pragma mark -


@interface SVSiteSubtitle : SVTitleBox
@end
