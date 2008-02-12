#import "AppController.h"

#import "AmazonOperation.h"
#import "AmazonItemLookup.h"
#import "AmazonListLookup.h"

#import "AmazonItem.h"
#import "AmazonImage.h"


@implementation AppController

+ (void)initialize
{
	[AmazonOperation setAccessKeyID: @"198Z9G3EA70GMSBA6XR2"];
}

- (IBAction)makeRequest:(id)sender
{
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	
	AmazonStoreCountry store = [[values valueForKey: @"store"] intValue];
	
	NSDictionary *parameters = 
		[NSDictionary dictionaryWithObjectsAndKeys: [values valueForKey: @"parameter1Value"],
													[values valueForKey: @"parameter1Key"],
													[values valueForKey: @"parameter2Value"],
													[values valueForKey: @"parameter2Key"],
													nil];
	
	AmazonOperation *operation = [[AmazonOperation alloc] initWithStore: store
															  operation: [values valueForKey: @"operation"]
															 parameters: parameters];
	[operation loadWithDelegate: self];
}

- (IBAction)lookupItem:(id)sender
{
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	
	AmazonStoreCountry store = [[values valueForKey: @"store"] intValue];
	AmazonIDType idType = [[values valueForKey: @"idType"] intValue];
	
	AmazonItemLookup *itemLookup = [[AmazonItemLookup alloc] initWithStore: store
																	itemID: [values valueForKey: @"itemID"]
																	IDType: idType];
	[itemLookup loadWithDelegate: self];
}

- (IBAction)lookupList:(id)sender
{
	id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	
	AmazonStoreCountry store = [[values valueForKey: @"store"] intValue];
	AmazonListType listType = [[values valueForKey: @"listType"] intValue];
	NSString *listID = [values valueForKey: @"listID"];
	
	AmazonListLookup *lookupOp = [[AmazonListLookup alloc] initWithStore: store
																  listID: listID
															    listType: listType
															 productPage: 1];
	
	[lookupOp loadWithDelegate: self];
}

- (void)asyncObject:(id)request didFailWithError:(NSError *)error;
{
	[self setUrl: [[request requestURL] absoluteString]];
	
	NSAlert *alert = [NSAlert alertWithError: error];
	[alert runModal];
	
	[request release];
}

- (void)asyncObjectDidFinishLoading:(id)request;
{
	// Display the request
	[self setUrl: [[request requestURL] absoluteString]];
	[self setResult: [[request XMLDoc] XMLStringWithOptions: NSXMLNodePrettyPrint]];
	
	// If it was an item lookup, output the result
	if ([request isKindOfClass: [AmazonItemLookup class]])
	{
		[request requestError];
		
		AmazonItem *returnedItem = [[request returnedItems] objectAtIndex: 0];
		[self setItemLookupResult: returnedItem];
		
		// Begin downloading the image
		//[[returnedItem largeImage] loadWithDelegate: self];
	}
	else if ([request isKindOfClass: [AmazonListLookup class]])
	{
		//NSArray *results = [request returnedItems];
		
	}
	
	// Close the request
	[request release];
}

- (NSString *)url {
    return [[_url retain] autorelease];
}

- (void)setUrl:(NSString *)value {
    if (_url != value) {
        [_url release];
        _url = [value copy];
    }
}

- (NSString *)result {
    return [[_result retain] autorelease];
}

- (void)setResult:(NSString *)value {
    if (_result != value) {
        [_result release];
        _result = [value copy];
    }
}

- (AmazonItem *)itemLookupResult { return _itemLookupResult; }

- (void)setItemLookupResult:(AmazonItem *)result
{
	if (result == _itemLookupResult)
		return;
	
	[_itemLookupResult release];
	_itemLookupResult = [result retain];
}

@end
