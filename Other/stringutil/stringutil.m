#import <Foundation/Foundation.h>
#include <unistd.h>


extern char *optarg;
extern int optind;
extern int optopt;
extern int opterr;
extern int optreset;

@interface NSString ( charset )

- (NSStringEncoding)encodingFromCharset;
+ (NSString *)charsetFromEncoding:(NSStringEncoding)anEncoding;

@end

@implementation NSString ( charset )

- (NSStringEncoding)encodingFromCharset
{
	CFStringEncoding cfEncoding
	= CFStringConvertIANACharSetNameToEncoding((CFStringRef)self);
	NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
	return encoding;
}

+ (NSString *)charsetFromEncoding:(NSStringEncoding)anEncoding
{
	CFStringEncoding encoding = CFStringConvertNSStringEncodingToEncoding(anEncoding);
	CFStringRef result = CFStringConvertEncodingToIANACharSetName(encoding);
	return (NSString *)result;
}

@end

void usage(const char *appName)
{
	printf("%s: [-v] [-t] [-i inputCharacterSet] [-o outputCharacterSet] file [ file2 ... ]\n", appName);
	printf("characters set, e.g. US-ASCII, ISO-8859-1, UTF-8, UTF-16BE, UTF-16LE, UTF-16\n");
	printf("v: verbose mode\n");
	printf("t: test mode, do not write out replacement files\n");
}

int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	const char *appName = argv[0];
	
	if (argc < 2)
	{
		usage(appName);
		exit(1);
	}

	BOOL verbose = NO;
	BOOL test = NO;
	char ch;
	
	// Default to UTF-8
	NSString *iEncoding = @"UTF-8";
	NSString *oEncoding = @"UTF-8";
	NSStringEncoding inputEncoding  = NSUTF8StringEncoding;
	NSStringEncoding outputEncoding = NSUTF8StringEncoding;

	while ((ch = getopt(argc, argv, "i:o:vt")) != -1) {
		switch (ch) {
			case 'v':
				verbose = YES;
				break;
			case 't':
				test = YES;
				break;
			case 'i':
			{
				iEncoding = [NSString stringWithUTF8String:optarg];
				inputEncoding = [iEncoding encodingFromCharset];
				
				if (kCFStringEncodingInvalidId == inputEncoding)
				{
					printf("%s: invalid input encoding '%s'\n", argv[0], optarg);
					exit(1);
				}
				break;
			}
			case 'o':
			{
				oEncoding = [NSString stringWithUTF8String:optarg];
				outputEncoding = [oEncoding encodingFromCharset];
				
				if (kCFStringEncodingInvalidId == outputEncoding)
				{
					printf("%s: invalid output encoding '%s'\n", argv[0], optarg);
					exit(1);
				}
				break;
			}
			case '?':
			default:
				usage(appName);
		}
	}
	if (verbose)
	{
		printf("%s: input encoding = %x\n", appName, inputEncoding);
		printf("%s: output encoding = %x\n", appName, outputEncoding);
	}					
	
	// Skip past these arguments
	argc -= optind;
	argv += optind;
	
	int i;
	for ( i = 0 ; i < argc ; i++ )
	{
		NSString *path = [NSString stringWithUTF8String:argv[i]];

		if ([[NSFileManager defaultManager] isReadableFileAtPath:path])
		{
			NSStringEncoding enc = inputEncoding;
			NSData *data = [NSData dataWithContentsOfFile:path];
			if (nil != data)
			{
				// Override: if the first two bytes look like UTF-16 than use that!
				unsigned short firstTwoBytes;
				[data getBytes:&firstTwoBytes length:2];
				if (enc != NSUnicodeStringEncoding && (firstTwoBytes == 0xFFFE || firstTwoBytes == 0xFEFF))
				{
					enc = NSUnicodeStringEncoding;

					if (verbose)
					{
						printf("%s", [[NSString stringWithFormat:@"File was actually UTF-16: %@\n", path] UTF8String]);
					}	
				}

				NSString *string = [[[NSString alloc] initWithData:data encoding:enc] autorelease];
				if (nil != string)
				{
					if (!test)
					{
						if (outputEncoding != enc)	// only rewrite if we are writing to a new encoding
						{
							// re-write file in desired output encoding
							NSError *outError = nil;
							NSData *newData = [string dataUsingEncoding:outputEncoding];
							BOOL written = [newData writeToFile:path options: NSAtomicWrite error:&outError];
							if (written)
							{
								if (verbose)
								{
									printf("%s", [[NSString stringWithFormat:@"Re-wrote file at %@\n", path] UTF8String]);
								}	
							}
							else
							{
								printf("%s", [[NSString stringWithFormat:@"Unable to write to %@: %@\n", path, [outError localizedDescription]] UTF8String]);
							}
						}
						else
						{
							if (verbose)
							{
								printf("%s", [[NSString stringWithFormat:@"Did not need to write out %@\n", path] UTF8String]);
							}					
						}
					}
					else
					{
						// Do nothing but announce if verbose
						
						if (verbose)
						{
							printf("%s", [[NSString stringWithFormat:@"Read file at %@\n", path] UTF8String]);
						}					
					}

				}
				else
				{
					NSString *encodingDescription = iEncoding;
					if (enc != inputEncoding)
					{
						encodingDescription = [NSString stringWithFormat:@"%@ or UTF-16", iEncoding];
					}
					printf("%s", [[NSString stringWithFormat:@"Unable to read file %@ with encoding %@\n", path, encodingDescription] UTF8String]);
				}
				
			}
			else
			{
				printf("Cannot read data at path %s\n",argv[i]);
			}
		}
		else
		{
			printf("Cannot read file at path %s\n",argv[i]);
		}

	}
	[pool release];
    return 0;
}
