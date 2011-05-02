//
//  KTFeedbackReporter.h
//  Sandvox
//
//  Created by Dan Wood on 7/7/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSFeedbackReporter.h"

@interface KTFeedbackReporter : KSFeedbackReporter {

	BOOL		_attachValidation;
}

@property (nonatomic, assign) BOOL attachValidation;

@end
