//
//  SVHTMLValidator.h
//  Sandvox
//
//  Created by Mike on 30/11/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
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

+ (ValidationState)validateFragment:(NSString *)fragment docType:(KTDocType)docType error:(NSError **)outError;

// Support
+ (NSString *)HTMLStringWithFragment:(NSString *)fragment docType:(KTDocType)docType;

@end


@interface SVRemoteHTMLValidator : SVHTMLValidator
@end