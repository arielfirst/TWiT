//
//  Enclosure.m
//  TWiT.tv
//
//  Created by Stuart Moore on 1/3/13.
//  Copyright (c) 2013 Stuart Moore. All rights reserved.
//

#import "Enclosure.h"
#import "Episode.h"

#define folder @"Downloads"

@implementation Enclosure

@dynamic path, quality, subtitle, title, type, url, episode;

@synthesize downloadPath = _downloadPath;
@synthesize downloadingFile = _downloadingFile, downloadConnection = _downloadConnection;
@synthesize expectedLength = _expectedLength, downloadedLength = _downloadedLength;

- (void)prepareForDeletion
{
    if([NSFileManager.defaultManager fileExistsAtPath:self.path])
        [NSFileManager.defaultManager removeItemAtPath:self.path error:nil];
}

#pragma mark - Download

- (void)download
{
    NSURL *url = [NSURL URLWithString:self.url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    self.downloadConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    
    if(!self.downloadConnection)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error!" message:@"Please check your internet connection"  delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
        
        [alert show];
    }
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    NSURL *url = [NSURL URLWithString:self.url];
    NSString *downloadDir = [[self.applicationDocumentsDirectory URLByAppendingPathComponent:folder] path];
    NSString *downloadPath = [downloadDir stringByAppendingPathComponent:url.lastPathComponent];
    
    if(![NSFileManager.defaultManager fileExistsAtPath:downloadDir])
        [NSFileManager.defaultManager createDirectoryAtPath:downloadDir withIntermediateDirectories:NO attributes:nil error:nil];
    
    if (![NSFileManager.defaultManager fileExistsAtPath:downloadPath])
        [NSFileManager.defaultManager createFileAtPath:downloadPath contents:nil attributes:nil];
    
    self.downloadPath = downloadPath;
    self.expectedLength = response.expectedContentLength;
    self.downloadedLength = 0;
    
    self.downloadingFile = [NSFileHandle fileHandleForWritingAtPath:self.downloadPath];
    [self.downloadingFile seekToEndOfFile];
}
-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    [self.downloadingFile seekToEndOfFile];
    [self.downloadingFile writeData:data];
    
    self.downloadedLength += data.length;
    
    [NSNotificationCenter.defaultCenter postNotificationName:@"enclosureDownloadDidReceiveData" object:self];
}

- (void)cancelDownload
{
    [self.downloadConnection cancel];
    
    if([NSFileManager.defaultManager fileExistsAtPath:self.downloadPath])
        [NSFileManager.defaultManager removeItemAtPath:self.downloadPath error:nil];
    
    [self closeDownload];
    [NSNotificationCenter.defaultCenter postNotificationName:@"enclosureDownloadDidFail" object:self];
}
-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if([NSFileManager.defaultManager fileExistsAtPath:self.downloadPath])
        [NSFileManager.defaultManager removeItemAtPath:self.downloadPath error:nil];
    
    [self closeDownload];
    [NSNotificationCenter.defaultCenter postNotificationName:@"enclosureDownloadDidFail" object:self];
}
-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    self.path = self.downloadPath;
    [self.managedObjectContext save:nil];
    
    [self closeDownload];
    [NSNotificationCenter.defaultCenter postNotificationName:@"enclosureDownloadDidFinish" object:self];
}
- (void)closeDownload
{
    self.downloadPath = nil;
    
    self.expectedLength = 0;
    self.downloadedLength = 0;
    
    [self.downloadingFile closeFile];
    self.downloadingFile = nil;
    self.downloadConnection = nil;
}

- (void)deleteDownload
{
    if([NSFileManager.defaultManager fileExistsAtPath:self.path])
        [NSFileManager.defaultManager removeItemAtPath:self.path error:nil];
    
    self.path = nil;
    [self.managedObjectContext save:nil];
}

#pragma mark - Helpers

- (NSURL*)applicationDocumentsDirectory
{
    return [[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
