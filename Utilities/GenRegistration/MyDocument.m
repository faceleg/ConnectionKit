//
//  MyDocument.m
//  GenRegistration
//
//  Created by Dan Wood on 10/27/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "RegGenerator.h"
#import "MyDocument.h"

static NSArray *sKeywordArray = nil;



@implementation MyDocument

- (NSArray *)sharedKeywordArray
{
	if (nil == sKeywordArray)
	{
		NSString *path = [[NSBundle mainBundle] pathForResource:@"keywords-5003" ofType:@"plist"];
		sKeywordArray = [[NSArray alloc] initWithContentsOfFile:path];
		NSAssert(sKeywordArray != nil, @"unable to load keywords list");
	}
	return sKeywordArray;
}

+ (void) initialize
{
	[MyDocument setKeys:
        [NSArray arrayWithObjects: @"licenseeTypeMatrixValue", @"licenseeName", @"anonymousIndex", @"licenseVersion", @"date", nil]
        triggerChangeNotificationsForDependentKey: @"canGenerate"];

	[MyDocument setKeys:
        [NSArray arrayWithObjects: @"licenseString", nil]
        triggerChangeNotificationsForDependentKey: @"validCode"];
	
}	

// For bindings, test if code is valid or not
- (BOOL) validCode;
{
	if (nil == [self licenseString] || [[self licenseString] isEqualToString:@""])
	{
		return YES;
	}
	return [MyDocument codeIsValid:[self licenseString]];
}


- (BOOL) canGenerate
{
	if (named == [self licenseeTypeMatrixValue]
		&& (nil == [self licenseeName] || [[self licenseeName] isEqualToString:@""]))
	{
		[self setReasonWhy:@"Need to specify a licensee name"];
		return NO;
	}
	if (anonymous == [self licenseeTypeMatrixValue]
		&& 0 == [self anonymousIndex])
	{
		[self setReasonWhy:@"Need to indicate a license number"];
		return NO;
	}
	
	int daysSinceNow = [[self date] timeIntervalSinceDate:[NSDate date]] / (60 * 60 * 24);

	if (0 == [self licenseVersion] && daysSinceNow < 1)
	{
		[self setReasonWhy:@"Version 0 license needs expiration date in the future"];
		return NO;	// can't be trial license with expiration date in the past
	}
	if (0 != [self licenseVersion] && daysSinceNow > 0)
	{
		[self setReasonWhy:@"License needs issuing date now or in the past"];
		return NO;	// can't be regular license with issue date in the future
	}
	[self setReasonWhy:@""];
	return YES;
}

#pragma mark -
#pragma mark Calculation

+ (int) checksum:(NSString *)aWord withPrime:(int)aPrime
{
	int len = [aWord length];
	len = MIN(len, 12);			// Don't check past 12th character, only 12 will fit into 64 bits
	NSString *lowerWord = [aWord lowercaseString];
	long long total = 0;
	int i;
	for ( i = 0 ; i < len ; i++ )
	{
		unichar theChar = [lowerWord characterAtIndex:i] - 'a';
		total *= 26;
		total += theChar;		// basically make it like a 5-bit number
	}
	return total % aPrime;
}

+ (BOOL) codeIsValid:(NSString *)aCode
{
	return [self codeIsValid:aCode
					   named:nil
					licensee:nil
					   index:nil
					 version:nil
						date:nil
						type:nil
					  source:nil
						hash:nil
						 pro:nil
					   seats:nil];
}

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
			   seats:(int *)outSeats
{
	// take out punctuation, multiple spaces, etc.
	NSArray *codeComponents = [aCode componentsSeparatedByString:@" "];
	int count = [codeComponents count];
	if (count <  4)
	{
		NSLog(@"code doesn't have enough components");
		return NO;
	}
	
	int flags		= [MyDocument checksum:[codeComponents objectAtIndex:count-2] withPrime:theBigPrime];
	
	int version = flags & versionMask;
	BOOL named = 0 != (flags & namedMask);
	int paymentIndex = (flags & paymentMask) / paymentMask;
	BOOL pro = (flags & proMask) / proMask;
	int licenseIndex = (flags & licenseMask) / 8;
		
	long long stringChecksumTotal = 0;

	int i;
	for ( i = 0 ; i < count-1; i++ )
	{
		NSString *word = [codeComponents objectAtIndex:i];
		NSString *cleanedWord = [[word removeCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]] lowercaseString];

		int length = [cleanedWord length];
		// Test checksum < 256, len >= 3 except for name components
		if (!named || (i >= count - 3))
		{
			int wordChecksum = [MyDocument checksum:cleanedWord withPrime:theBigPrime];
			if (length < 3)
			{
				NSLog(@"word %@ < 3 chars", cleanedWord);
				return NO;
			}
			if (wordChecksum > 255)
			{
				NSLog(@"word %@ checksum illegal, = %d", cleanedWord, wordChecksum);
				return NO;
			}
		}

		int charIndex;
		for (charIndex = 0 ; charIndex < length ; charIndex++)
		{
			int c = [cleanedWord characterAtIndex:charIndex] - 'a';
			stringChecksumTotal = stringChecksumTotal * 2 + c;		// shift each one by 1 bit
		}
	}
	int expectedChecksum = stringChecksumTotal % the8BitPrime;
	NSString *finalWord = [codeComponents objectAtIndex:count-1];
	int checksumValue = [MyDocument checksum:finalWord withPrime:theBigPrime];
	if (expectedChecksum != checksumValue)
	{
		NSLog(@"expectedChecksum %d != given checksum %d from %@", expectedChecksum, checksumValue, finalWord);
		return NO;
	}
	
	int fortnights	= [MyDocument checksum:[codeComponents objectAtIndex:count-3] withPrime:theBigPrime];
	float secondsPerFortnight = 14 * 24 * 60 * 60;
	NSTimeInterval timeIntervalToAdd = (float)fortnights * secondsPerFortnight;
	NSDate *embeddedDate = [NSDate dateWithString:REFERENCE_TIMESTAMP];
	embeddedDate = [embeddedDate addTimeInterval:timeIntervalToAdd ];
	
	NSTimeInterval sinceStoredDate = [[NSDate date] timeIntervalSinceDate:embeddedDate];

	int daysSince = sinceStoredDate / (60 * 60 * 24);
	if (0 == version)	// make sure current time is not AFTER the given date
	{
		if (daysSince > 0)
		{
			NSLog(@"It looks like you've expired");
			return NO;
		}
	}
	else	// Make sure that the given date is in the past
	{
		if (daysSince < 0)
		{
			NSLog(@"It looks like the generation date is in the future; this is bad?");
			return NO;
		}
	}
	
	int seats = 0;
	if (siteLicense == licenseIndex)
	{
		seats	= [MyDocument checksum:[codeComponents objectAtIndex:count-4] withPrime:theBigPrime];
		if (seats < 5 || seats > 255)
		{
			NSLog(@"Invalid site-license seats number");
			return NO;
		}
	}

	// If everything is valid, return new values
	if (outNamed)
	{
		*outNamed = named;
	}
	if (outLicensee && named)
	{
		NSArray *justName = [codeComponents subarrayWithRange:NSMakeRange(0,count-( (siteLicense == licenseIndex) ? 4 : 3))];
		NSString *joined = [justName componentsJoinedByString:@" "];
		*outLicensee = [joined capitalizedString];
	}
	if (outIndex && !named)
	{
		int loByte = [MyDocument checksum:[codeComponents objectAtIndex:0] withPrime:theBigPrime];
		int hiByte = [MyDocument checksum:[codeComponents objectAtIndex:1] withPrime:theBigPrime];
		*outIndex = hiByte * 256 + loByte;
	}
	if (outVersion)
	{
		*outVersion = version;
	}
	if (outDate)
	{
		*outDate = embeddedDate;
	}
	if (outType)
	{
		*outType = licenseIndex;
	}
	if (outSource)
	{
		*outSource = paymentIndex;
	}
	if (nil != outHash)
	{
		*outHash = [RegGenerator hashStringFromLicenseString:aCode];
	}
	if (outPro)
	{
		*outPro = pro;
	}
	if (outSeats)
	{
		*outSeats = seats;
	}
	return YES;
}

#pragma mark -
#pragma mark NSDocument Stuff

- (id)init
{
    self = [super init];
    if (self) {

		srandom([NSDate timeIntervalSinceReferenceDate]);

		// Seed the index from user defaults
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[self setAnonymousIndex:[defaults integerForKey:@"nextLicenseKeyIndex"]];
		
		[self setLicenseeTypeMatrixValue:1];
		[self setDate:[NSDate date]];
		[self setLicenseeName:@""];
		
		[self setLicenseVersion:[defaults integerForKey:@"licenseVersion"]];
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    return nil;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    return YES;
}

#pragma mark -
#pragma mark Actions


- (IBAction) generateLicense:(id)sender;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setInteger:[self anonymousIndex]+1 forKey:@"nextLicenseKeyIndex"];
	[defaults setInteger:[self licenseVersion] forKey:@"licenseVersion"];
	[defaults synchronize];
	
	NSString *aHash = nil;

	NSString *code = [RegGenerator generateLicenseCodeFromWords:[self sharedKeywordArray]
														   name:[self licenseeTypeMatrixValue]
															pro:[self proValue]
													  licensee:[self licenseeName]
												  licenseIndex:[self anonymousIndex]
													   version:[self licenseVersion]
														  date:[self date]
												   licenseType:[self licenseTypeMatrixValue]
														  seats:[self seatsValue]
												 licenseSource:[self licenseSourceMatrixValue]
												 returningHash:&aHash];
	[self setLicenseString:code];
	[self setBlacklistCode:aHash];
}

- (IBAction) decodeLicense:(id)sender;
{
	int named = 99, vers = 99, type = 99, source = 99, pro = 99;
	NSString *licensee = nil;
	NSString *hash = nil;
	NSDate *aDate = nil;
	int index = 0;
	int seats = 0;
	
	// will put license information into variables ONLY if the code is valid.
	BOOL valid = [MyDocument codeIsValid:[self licenseString]
								   named:&named
								licensee:&licensee
								   index:&index
								 version:&vers
									date:&aDate
									type:&type
								  source:&source
									hash:&hash
									 pro:&pro
								   seats:&seats];
	if (valid)
	{
		[self setDate:aDate];
		[self setProValue:pro];
		[self setLicenseeName:licensee];
		[self setLicenseeTypeMatrixValue:(named ? 1 : 0)];
		[self setAnonymousIndex:index];
		[self setLicenseVersion:vers];
		[self setLicenseTypeMatrixValue:type];
		[self setLicenseSourceMatrixValue:source];
		[self setBlacklistCode:hash];
		[self setSeatsValue:seats];
	}
	else
	{
		NSBeep();
	}
}

#pragma mark -
#pragma mark Accessors


- (int)licenseeTypeMatrixValue
{
    return myLicenseeTypeMatrixValue;
}

- (void)setLicenseeTypeMatrixValue:(int)aLicenseeTypeMatrixValue
{
    myLicenseeTypeMatrixValue = aLicenseeTypeMatrixValue;
}

- (int)anonymousIndex
{
    return myAnonymousIndex;
}

- (void)setAnonymousIndex:(int)anAnonymousIndex
{
    myAnonymousIndex = anAnonymousIndex;
}

- (int)licenseVersion
{
    return myLicenseVersion;
}

- (void)setLicenseVersion:(int)aLicenseVersion
{
    myLicenseVersion = aLicenseVersion;
}

- (int)licenseTypeMatrixValue
{
    return myLicenseTypeMatrixValue;
}

- (void)setLicenseTypeMatrixValue:(int)aLicenseTypeMatrixValue
{
    myLicenseTypeMatrixValue = aLicenseTypeMatrixValue;
}

- (int)licenseSourceMatrixValue
{
    return myLicenseSourceMatrixValue;
}

- (void)setLicenseSourceMatrixValue:(int)aLicenseSourceMatrixValue
{
    myLicenseSourceMatrixValue = aLicenseSourceMatrixValue;
}


- (int)proValue
{
    return myProValue;
}

- (void)setProValue:(int)aProValue
{
    myProValue = aProValue;
}

- (NSDate *)date
{
    return myDate; 
}

- (void)setDate:(NSDate *)aDate
{
    [aDate retain];
    [myDate release];
    myDate = aDate;
}

- (NSString *)licenseeName
{
    return myLicenseeName; 
}

- (void)setLicenseeName:(NSString *)aLicenseeName
{
    [aLicenseeName retain];
    [myLicenseeName release];
    myLicenseeName = aLicenseeName;
}

- (NSString *)licenseString
{
    return myLicenseString; 
}

- (void)setLicenseString:(NSString *)aLicenseString
{
    [aLicenseString retain];
    [myLicenseString release];
    myLicenseString = aLicenseString;
}

- (NSString *)reasonWhy
{
    return myReasonWhy; 
}

- (void)setReasonWhy:(NSString *)aReasonWhy
{
    [aReasonWhy retain];
    [myReasonWhy release];
    myReasonWhy = aReasonWhy;
}

- (NSString *)blacklistCode
{
    return myBlacklistCode; 
}

- (void)setBlacklistCode:(NSString *)aBlacklistCode
{
    [aBlacklistCode retain];
    [myBlacklistCode release];
    myBlacklistCode = aBlacklistCode;
}


- (int)seatsValue
{
    return mySeatsValue;
}

- (void)setSeatsValue:(int)aSeatsValue
{
    mySeatsValue = aSeatsValue;
}

@end
