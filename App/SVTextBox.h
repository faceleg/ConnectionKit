//
//  SVTextBox.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"
#import "SVRichText.h"


@interface SVTextBox :  SVGraphic  

#pragma mark Body Text
@property(nonatomic, retain, readonly) SVRichText *body;


#pragma mark Options
@property(nonatomic, copy) NSNumber *isBlockQuote;


@end


#pragma mark -


@interface SVTextBoxBody : SVRichText
@end



