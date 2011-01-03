//
//  RegGenerator.h
//  GenRegistration
//
//  Created by Dan Wood on 11/11/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define the16BitPrime	65521
#define theBigPrime		5003
#define the8BitPrime	251


enum { singleLicense, householdLicense, siteLicense, worldwideLicense };
enum { comp, kagi, paypal, store };
enum { anonymous, named };

enum {
	versionMask = 1+2+4, // 0 = trial license; 1 = license for v. 1; ... 7 = perpetual comp license?
    licenseMask = 8+16,
	paymentMask = 32,	// paypal or other
	proMask = 64,		// pro or normal
	namedMask = 128		// if on, then this is somebody's name; if off, it's an anonymous index
};


/*
 Note: the dictionary we are using has a list of words length 3 to 7, hand-culled down
 to try and reduce the number of bizzare words!
 
 With each letter contributing to almost 5 bits, we can fit 64/5 = 12 characters into a 64-bit long long.
 
 */



#warning ----- MAKE SURE TIMESTAMP CORRESPONDS TO CODE IN OTHER FILES!
// See: Sandvox KTAppDelegate, RegGenerator RegGenerator.h, 
#define REFERENCE_TIMESTAMP @"2006-01-01 00:00:00 -0800"


@interface NSString ( Something )
- (NSString *) stringByRemovingCharactersInSet:(NSCharacterSet *)set;
- (NSString *) condenseMultipleCharactersFromSet:(NSCharacterSet *)aMultipleSet into:(unichar)aReplacement;
- (NSString *) removeCharactersInSet:(NSCharacterSet *)aBadSet;
- (NSString *) condenseWhiteSpace;
@end
@interface NSArray ( randomness )
- (id) randomObject;
@end


@interface RegGenerator : NSObject {
}

+ (NSString *)hashStringFromLicenseString:(NSString *)aCode;

+ (NSString *)generateLicenseCodeFromWords:(NSArray *)keywords
									  name:(BOOL)aNamed
									   pro:(BOOL)aPro
								  licensee:(NSString *)aLicensee	// N/A if anonymous
							  licenseIndex:(int)anIndex			// N/A if not anonymous
								   version:(int)aVersion			// 0 = trial, expires in future
									  date:(NSDate *)aDate		// future for trial versions
							   licenseType:(int)aLicenseType
									 seats:(int)aSeats
							 licenseSource:(int)aLicenseSource
							 returningHash:(NSString **)outHash;




@end
