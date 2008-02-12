//  ====================================================================== 	//
//  NTSUTaskController.m														//
//  ====================================================================== 	//

#import "NTSUTaskController.h"
#import <Security/AuthorizationTags.h>
#import "NSString-Utilities.h"
#include <sys/wait.h>

@interface NTSUTaskController (Private)
- (BOOL)isAuthenticated:(NSArray *)forCommands;
- (BOOL)authenticate:(NSArray *)forCommands;
- (void)deauthenticate;
- (BOOL)fetchPassword:(NSArray *)forCommands;
@end

@implementation NTSUTaskController

+ (id)sharedInstance;
{
    static id sharedTask = nil;

    if (sharedTask == nil)
        sharedTask = [[NTSUTaskController alloc] init];

    return sharedTask;
}

- (id)init
{
    AuthorizationRights rights;
    OSStatus err = 0;

    self = [super init];

    rights.count=0;
    rights.items = NULL;
    err = AuthorizationCreate(&rights, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);

    return self;
}

- (void)dealloc
{
    [self deauthenticate];
    [super dealloc];
}

- (BOOL)executeCommand:(BOOL)asynchronous pathToCommand:(NSString *)pathToCommand withArgs:(NSArray *)arguments delegate:(id)delegate;
{
    BOOL result = YES;

    if (![self authenticate:[NSArray arrayWithObject:pathToCommand]])
        result = NO;
    else
    {
        BOOL sendToDelegate = (delegate && [delegate respondsToSelector:@selector(delegate_handleTaskOutput:)]);
        OSStatus err;
        unsigned i;
        FILE* file=nil;
        const char* args[31]; // can only handle 30 arguments to a given command

        if (arguments == nil || [arguments count] == 0)
            err = AuthorizationExecuteWithPrivileges(authorizationRef, [pathToCommand UTF8String], 0, NULL, &file);
        else
        {
            i=0;
            while (i < [arguments count] && i < 30)
            {
                args[i] = [[arguments objectAtIndex:i] UTF8String];
                i++;
            }
            args[i] = NULL;

            err = AuthorizationExecuteWithPrivileges(authorizationRef, [pathToCommand UTF8String], 0, (char* const*)args, &file);
        }

        if (err == noErr)
        {
            if (!asynchronous)
            {
                int numR;
                const int bufferSize = 512;
                char buffer[bufferSize+1]; // add one for /0 terminator
                NSString* outString;
                int status;

                do
                {
                    numR = fread(buffer, 1, bufferSize, file);

                    if (numR > 0)
                    {
                        buffer[numR] = 0; // null terminate
                        outString = [NSString stringWithUTF8String:buffer];

                        if (sendToDelegate)
                            [delegate delegate_handleTaskOutput:outString];
                    }
                } while (numR == bufferSize);  // breaks out when reads less than the buffer size, either error or eof

                wait(&status);
            }

            fclose(file);
        }
        else
        {
            NSLog(@"Error %d in AuthorizationExecuteWithPrivileges",err);
            result = NO;
        }
    }

    return result;
}

@end

@implementation NTSUTaskController (Private)

- (BOOL)isAuthenticated:(NSArray *)forCommands
{
    BOOL authorized = NO;
    int cnt = [forCommands count];

    if (cnt)
    {
        AuthorizationRights rights;
        AuthorizationRights *authorizedRights;
        AuthorizationItem *items = malloc(sizeof(AuthorizationItem) * cnt);
        char paths[20][512]; // only handles upto 20 commands with paths upto 512 characters in length
        OSStatus err = 0;
        int i = 0;

        while (i < cnt && i < 20)
        {
            [[forCommands objectAtIndex:i] getCString:paths[i] maxLength:511];

            items[i].name = kAuthorizationRightExecute;
            items[i].value = paths[i];
            items[i].valueLength = [[forCommands objectAtIndex:i] cStringLength];
            items[i].flags = 0;

            i++;
        }

        rights.count = cnt;
        rights.items = items;
        err = AuthorizationCopyRights(authorizationRef, &rights, kAuthorizationEmptyEnvironment, kAuthorizationFlagExtendRights, &authorizedRights);

        authorized = (err == errAuthorizationSuccess);

        if (authorized)
            AuthorizationFreeItemSet(authorizedRights);

        free(items);
    }

    return authorized;
}

- (void)deauthenticate
{
    if (authorizationRef)
    {
        AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
        authorizationRef = NULL;
    }
}

- (BOOL)fetchPassword:(NSArray *)forCommands
{
    BOOL authorized = NO;
    int cnt = [forCommands count];

    if (cnt)
    {
        AuthorizationRights rights;
        AuthorizationRights *authorizedRights;
        AuthorizationItem *items = malloc(sizeof(AuthorizationItem) * cnt);
        char paths[20][512];
        OSStatus err = 0;
        int i = 0;

        while( i < cnt && i < 20 )
        {
            [[forCommands objectAtIndex:i] getCString:paths[i] maxLength:511];

            items[i].name = kAuthorizationRightExecute;
            items[i].value = paths[i];
            items[i].valueLength = [[forCommands objectAtIndex:i] cStringLength];
            items[i].flags = 0;

            i++;
        }

        rights.count = cnt;
        rights.items = items;
        err = AuthorizationCopyRights(authorizationRef, &rights, kAuthorizationEmptyEnvironment, (kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights), &authorizedRights);

        authorized = (err == errAuthorizationSuccess);

        if (authorized)
            AuthorizationFreeItemSet(authorizedRights);

        free(items);
    }

    return authorized;
}

- (BOOL)authenticate:(NSArray *)forCommands
{
    if (![self isAuthenticated:forCommands])
        [self fetchPassword:forCommands];

    return [self isAuthenticated:forCommands];
}

@end
