#import <Foundation/Foundation.h>
#import "RegGenerator.h"
#import <CoreServices/CoreServices.h>
#import "MyDocument.h"

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	// Try to seed the random number generator based on microseconds.  
	UnsignedWide micr;
	Microseconds(&micr);
	srandom(micr.lo ^ micr.hi);
	
	// But what if this is called twice in the same microsecond?
	
	
	if (1 == argc)
	{
		printf("usage: %s [-v] [-h] [-name name] [-index n] [-pro] [-version n] [-date date] \n\
[-type 0..3|single|household|site|world] [-seats 5..255] [-source 0..1|comp|paypal] word_list_file\n\n\
Either name or index must be specified.\n\
-h = generate hash, not code (or return hash if -c)\n\
-v = verbose output\n\
-check regcode, to check an existing code\n\
Date is in format like:  2001-03-24 10:45:32 +0600", argv[0]);
		
		return 0;
	}
	
	BOOL verbose = NO;
	BOOL aNamed = NO;
	BOOL aPro = NO;
	int seats = 0;
	NSString *licensee = nil;
	int licenseIndex = -1;
	int version = 1;					// default version 1
	NSDate *date = [NSDate date];		// default now, which doesn't make sense for trial version!
	int licenseType = singleLicense;	// default single
	int licenseSource = comp;			// default comp
	BOOL returnHashInstead = NO;		// default to return the code
	NSString *pathOfWordList = nil;
	NSString *codeToCheck = nil;
	NSArray *keywordArray = nil;
	
	int i = 1;		// skip zero, the program itself
	while (i < argc)
	{
		const char *arg = argv[i++];
		if ('-' == arg[0])
		{
			const char *cmd = &arg[1];	// skip the dash
			
			if (0 == strcmp(cmd, "h"))
			{
				returnHashInstead = YES;
			}
			else if (0 == strcmp(cmd, "v"))
			{
				verbose = YES;
			}
			else if (0 == strcmp(cmd, "pro"))
			{
				aPro = YES;
			}
			else	// Expecting rgument after command
			{
				const char *value = argv[i++];
				
				if (0 == strcmp(cmd, "check") && strlen(value))
				{
					codeToCheck = [NSString stringWithUTF8String:value];
				}
				else if (0 == strcmp(cmd, "name") && strlen(value))
				{
					licensee = [NSString stringWithUTF8String:value];
					aNamed = YES;
				}
				else if (0 == strcmp(cmd, "index") && strlen(value))
				{
					licenseIndex = [[NSString stringWithUTF8String:value] intValue];
					aNamed = NO;
				}
				else if (0 == strcmp(cmd, "version") && strlen(value))
				{
					version = [[NSString stringWithUTF8String:value] intValue];
					if (version > 7)
					{
						fprintf(stderr, "Version cannot be greater than 7, it was: %s\n", value);
						return 1;
					}
				}
				else if (0 == strcmp(cmd, "seats") && strlen(value))
				{
					seats = [[NSString stringWithUTF8String:value] intValue];
					if (version > 255 || seats < 5)
					{
						fprintf(stderr, "seats must be between 5 and 255, it was: %s\n", seats);
						return 9;
					}
				}
				else if (0 == strcmp(cmd, "date") && strlen(value))
				{
					date = [NSDate dateWithString:[NSString stringWithUTF8String:value]];
					if (nil == date)
					{
						fprintf(stderr, "Unable to parse date: %s\n", value);
						return 2;
					}
				}
				else if (0 == strcmp(cmd, "type") && strlen(value))
				{
					NSString *token = [[NSString stringWithUTF8String:value] lowercaseString];
					NSScanner *intScanner = [NSScanner scannerWithString:token];
					if (![intScanner scanInt:&licenseType])	// try scanning directly as number first
					{
						NSArray *lookup = [NSArray arrayWithObjects:@"---", @"single", @"household", @"site", @"world", nil];
						licenseType = [lookup indexOfObject:token] - 1;
					}
					if (licenseType < 0 || licenseType > 3)
					{
						fprintf(stderr, "did not recognize licence type of: %s\n", value);
						return 3;
					}
				}
				else if (0 == strcmp(cmd, "source") && strlen(value))
				{
					NSString *token = [[NSString stringWithUTF8String:value] lowercaseString];
					NSScanner *intScanner = [NSScanner scannerWithString:token];
					if (![intScanner scanInt:&licenseSource])	// try scanning directly as number first
					{
						NSArray *lookup = [NSArray arrayWithObjects:@"---", @"comp", @"paypal", nil];
						licenseSource = [lookup indexOfObject:token] - 1;
					}

					if (licenseSource < 0 || licenseSource > 1)
					{
						fprintf(stderr, "did not recognize source of: %s\n", token);
						return 4;
					}
				}
			}
		}
		else	// no dash, this must be the wordlist file; use first one
		{
			if (nil == pathOfWordList)
			{
				pathOfWordList = [NSString stringWithUTF8String:arg];
			}
			else
			{
				fprintf(stderr, "path of word list already set to: %s\n", [pathOfWordList UTF8String]);
				return 5;
			}
		}
	}
	
	if (nil == codeToCheck)
	{
		if (!aNamed && licenseIndex < 0)
		{
			fprintf(stderr, "Need to specify either index or name\n");
			return 6;
		}

		if (seats && licenseType != siteLicense)
		{
			fprintf(stderr, "Seats can only be specified for a site license\n");
			return 10;
		}
		if (0 == seats && licenseType == siteLicense)
		{
			fprintf(stderr, "Need to specify seats for a site license.\n");
			return 11;
		}

		if (nil != pathOfWordList)
		{
			keywordArray = [[NSArray alloc] initWithContentsOfFile:pathOfWordList];
			
			if (nil == keywordArray)
			{
				fprintf(stderr, "Error reading keyword file at %s", [pathOfWordList UTF8String]);
				return 7;
			}
		}
		else
		{
			fprintf(stderr, "Need to specify the path of the keyword file.\n");
			return 8;
		}
	}
	NSString *returnedHash = nil;
	
	if (nil == codeToCheck)
	{
		NSString *code = [RegGenerator generateLicenseCodeFromWords:keywordArray
															   name:aNamed
																pro:aPro
														  licensee:licensee
													  licenseIndex:licenseIndex
														   version:version
															  date:date
													   licenseType:licenseType
															  seats:seats
													 licenseSource:licenseSource
													 returningHash:&returnedHash];

		if (verbose)
		{
			NSMutableString *string = [NSMutableString string];
			[string appendFormat:@"Word list file: %@\n", pathOfWordList];
			if (aNamed)
			{
				[string appendFormat:@"Name: %@\n", licensee];
			}
			else
			{
				[string appendFormat:@"Index: %d\n", licenseIndex];
			}
			[string appendFormat:@"Version: %d\n", version];
			if (nil != date)
			{
				[string appendFormat:@"Date: %@\n", date];
			}
			[string appendFormat:@"License Type: %d\n", licenseType];
			[string appendFormat:@"License Source: %d\n", licenseSource];
			[string appendFormat:@"Hash: %@\n", returnedHash];
			
			fprintf(stderr, [string UTF8String]);
		}

		if (returnHashInstead)
		{
			printf("%s", [returnedHash UTF8String]);
		}
		else
		{
			printf("%s", [code UTF8String]);
		}
	}
	else
	{
		int named = 99, vers = 99, type = 99, source = 99, pro = 99;
		NSString *licensee = nil;
		NSString *hash = nil;
		NSDate *aDate = nil;
		int index = 0;
		int seats = 0;
		
		// will put license information into variables ONLY if the code is valid.
		BOOL valid = [MyDocument codeIsValid:codeToCheck
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
		
		// Later, maybe verbosely show what the code is all about
		if (valid)
		{
			if (returnHashInstead)
			{
				printf("%s", [hash UTF8String]);
			}
			else
			{
				printf("OK");
			}
		}
		else
		{
			printf("BAD");
		}
	}
	
	[pool release];
    return 0;
}
