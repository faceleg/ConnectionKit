//
//  MyDocument.h
//  GenRegistration
//
//  Created by Dan Wood on 10/27/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MyDocument : NSDocument
{
	int myLicenseeTypeMatrixValue;
	int myAnonymousIndex;
	int myLicenseVersion;
	int myLicenseTypeMatrixValue;
	int myLicenseSourceMatrixValue;
	int myProValue;
	int mySeatsValue;
	NSString *myBlacklistCode;
	
	NSDate		*myDate;
	NSString	*myLicenseeName;
	NSString	*myLicenseString;
	
	NSString	*myReasonWhy;	// guide to why button is disabled
}
- (IBAction) generateLicense:(id)sender;
- (IBAction) decodeLicense:(id)sender;

- (int)seatsValue;
- (void)setSeatsValue:(int)aSeatsValue;

- (NSString *)blacklistCode;
- (void)setBlacklistCode:(NSString *)aBlacklistCode;

- (int)licenseeTypeMatrixValue;
- (void)setLicenseeTypeMatrixValue:(int)aLicenseeTypeMatrixValue;

- (int)anonymousIndex;
- (void)setAnonymousIndex:(int)anAnonymousIndex;

- (int)licenseVersion;
- (void)setLicenseVersion:(int)aLicenseVersion;

- (int)licenseTypeMatrixValue;
- (void)setLicenseTypeMatrixValue:(int)aLicenseTypeMatrixValue;

- (int)licenseSourceMatrixValue;
- (void)setLicenseSourceMatrixValue:(int)aLicenseSourceMatrixValue;

- (int)proValue;
- (void)setProValue:(int)aProValue;

- (NSDate *)date;
- (void)setDate:(NSDate *)aDate;

- (NSString *)licenseeName;
- (void)setLicenseeName:(NSString *)aLicenseeName;

- (NSString *)licenseString;
- (void)setLicenseString:(NSString *)aLicenseString;

- (NSString *)reasonWhy;
- (void)setReasonWhy:(NSString *)aReasonWhy;



- (BOOL) canGenerate;
- (BOOL) validCode;
+ (BOOL) codeIsValid:(NSString *)aCode;

+ (BOOL) codeIsValid:(NSString *)aCode
			   named:(int *)outNamed
			licensee:(NSString **)outLicensee
			   index:(int *)outIndex
			 version:(int *)outVersion
				date:(NSDate **)outDate		// expiration if version == 0
				type:(int *)outType
			  source:(int *)outSource
				hash:(NSString **)outHash
				 pro:(int *)outPro
			   seats:(int *)outSeats;

@end
