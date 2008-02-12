/* AppController */

#import <Cocoa/Cocoa.h>


@class AmazonItem;


@interface AppController : NSObject
{
	NSString	*_url;
	NSString	*_result;
	
	NSURLResponse *urlResponse;
	NSData *urlData;
	
	AmazonItem	*_itemLookupResult;
}

- (IBAction)makeRequest:(id)sender;
- (IBAction)lookupItem:(id)sender;
- (IBAction)lookupList:(id)sender;

- (NSString *)result;
- (void)setResult:(NSString *)value;

- (NSString *)url;
- (void)setUrl:(NSString *)value;

- (AmazonItem *)itemLookupResult;
- (void)setItemLookupResult:(AmazonItem *)result;
@end
