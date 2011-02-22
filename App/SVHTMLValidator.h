//
//  SVHTMLValidator.h
//  Sandvox
//
//  Created by Mike on 30/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KT.h"


typedef enum { 
	kValidationStateUnknown = 0,		// or empty string
	kValidationStateDisabled,			// for when we are not previewing, therefore no validation
	kValidationStateUnparseable, 
	kValidationStateValidationError, 
	kValidationStateLocallyValid, 
	kValidationStateVerifiedGood,
} ValidationState;


@interface SVHTMLValidator : NSObject
{

}

// Call +HTMLStringWithFragment:docType: first if you only have a fragment of HTML
+ (ValidationState)validateHTMLString:(NSString *)html docType:(NSString *)docType error:(NSError **)outError;

// Support
+ (NSString *)HTMLStringWithFragment:(NSString *)fragment docType:(NSString *)docType;

@end


@interface SVRemoteHTMLValidator : SVHTMLValidator
@end