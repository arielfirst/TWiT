//
//  Show.m
//  TWiT.tv
//
//  Created by Stuart Moore on 1/3/13.
//  Copyright (c) 2013 Stuart Moore. All rights reserved.
//

#import "NSManagedObjectContext+ConvenienceMethods.h"
#import "XMLReader.h"

#import "Show.h"
#import "Poster.h"
#import "Feed.h"
#import "Episode.h"
#import "Enclosure.h"

#define MAX_EPISODES 50

@implementation Show

@dynamic desc, email, favorite, hosts, phone, published, remind, schedule, sort, title, titleAcronym, titleInSchedule, website, albumArt, channel, episodes, feeds;

- (Poster*)poster
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"poster.path != nil"];
    NSSet *episodes = [self.episodes filteredSetUsingPredicate:pred];
    Episode *episode = episodes.anyObject;
    
    return episode.poster;
}

- (NSString*)scheduleString
{
    NSString *scheduleString = self.schedule;
    NSMutableArray *dayStrings = [NSMutableArray array];
    NSString *timeString = @"";
    if([scheduleString rangeOfString:@"@"].location != NSNotFound)
    {
        NSArray *daysAndTime = [scheduleString componentsSeparatedByString:@"@"];
        scheduleString = @"";
        
        int TZDiff = ([[NSTimeZone timeZoneWithName:@"America/Los_Angeles"] secondsFromGMT]
                      -[[NSTimeZone localTimeZone] secondsFromGMT])/60/60*100;
        
        int time = [[daysAndTime objectAtIndex:1] intValue];
        time -= TZDiff;
        BOOL nextDay = NO;
        if(time >= 2400)
        {
            time -= 2400;
            nextDay = YES;
        }
        
        if(time/100 == 0)
            timeString = [NSString stringWithFormat:@"12:%.2da", time%100];
        else if(time/100 <= 12)
            timeString = [NSString stringWithFormat:@"%d:%.2da", time/100, time%100];
        else
            timeString = [NSString stringWithFormat:@"%d:%.2dp", time/100-12, time%100];
        
        NSArray *days = [[daysAndTime objectAtIndex:0] componentsSeparatedByString:@","];
        for(NSString *dayString in days)
        {
            NSInteger day = -1;
            if([dayString isEqualToString:@"SU"])
                day = 1;
            else if([dayString isEqualToString:@"MO"])
                day = 2;
            else if([dayString isEqualToString:@"TU"])
                day = 3;
            else if([dayString isEqualToString:@"WE"])
                day = 4;
            else if([dayString isEqualToString:@"TH"])
                day = 5;
            else if([dayString isEqualToString:@"FR"])
                day = 6;
            else if([dayString isEqualToString:@"SA"])
                day = 7;
            if(day < 0)
                day += 7;
            
            if(nextDay)
            {
                day++;
                if(day >= 8)
                    day = 0;
            }
            
            if(days.count <= 2)
            {
                if(day == 1)
                    [dayStrings addObject:@"Sundays"];
                else if(day == 2)
                    [dayStrings addObject:@"Mondays"];
                else if(day == 3)
                    [dayStrings addObject:@"Tuesdays"];
                else if(day == 4)
                    [dayStrings addObject:@"Wednesdays"];
                else if(day == 5)
                    [dayStrings addObject:@"Thursdays"];
                else if(day == 6)
                    [dayStrings addObject:@"Fridays"];
                else if(day == 7)
                    [dayStrings addObject:@"Saturdays"];
            }
            else
            {
                if(day == 1)
                    [dayStrings addObject:@"Sun"];
                else if(day == 2)
                    [dayStrings addObject:@"Mon"];
                else if(day == 3)
                    [dayStrings addObject:@"Tues"];
                else if(day == 4)
                    [dayStrings addObject:@"Wed"];
                else if(day == 5)
                    [dayStrings addObject:@"Thur"];
                else if(day == 6)
                    [dayStrings addObject:@"Fri"];
                else if(day == 7)
                    [dayStrings addObject:@"Sat"];
            }
        }
        
        for(NSString *dayString in dayStrings)
        {
            scheduleString = [scheduleString stringByAppendingString:dayString];
            
            if(dayString != [dayStrings lastObject])
            {
                if(dayString != [dayStrings objectAtIndex:dayStrings.count-2])
                    scheduleString = [scheduleString stringByAppendingString:@", "];
                else
                    scheduleString = [scheduleString stringByAppendingString:@" & "];
            }
        }
        
        if([scheduleString isEqualToString:@"Mon, Tues, Wed, Thur & Fri"])
            scheduleString = @"Weekdays";
        else if([scheduleString isEqualToString:@"Saturdays & Sundays"])
            scheduleString = @"Weekends";
        
        scheduleString = [scheduleString stringByAppendingString:@" @ "];
        scheduleString = [scheduleString stringByAppendingString:timeString];
    }
    return scheduleString;
}

#pragma mark -

- (void)setFavorite:(BOOL)favorite
{    
    [self willChangeValueForKey:@"favorite"];
    [self setPrimitiveValue:@(favorite) forKey:@"favorite"];
    [self didChangeValueForKey:@"favorite"];
    
    [self.managedObjectContext save:nil];
}

- (void)setRemind:(BOOL)remind
{/*
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = [NSDate date];
    notification.timeZone = [NSTimeZone defaultTimeZone];
    
    notification.alertBody = @"Notification triggered";
    notification.alertAction = @"Details";
    
    NSDictionary *infoDict = @{ @"" : @"" };
    notification.userInfo = infoDict;
    
    [UIApplication.sharedApplication scheduleLocalNotification:notification];
    */
    
    [self willChangeValueForKey:@"remind"];
    [self setPrimitiveValue:@(remind) forKey:@"remind"];
    [self didChangeValueForKey:@"remind"];
    
    [self.managedObjectContext save:nil];
}

#pragma mark - Update Episodes

- (void)updateEpisodes
{
    for(Feed *feed in self.feeds)
    {
        NSMutableURLRequest *headerRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:feed.url]
                                                                     cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                                 timeoutInterval:60.0f];
        [headerRequest setHTTPMethod:@"HEAD"];
        [NSURLConnection sendAsynchronousRequest:headerRequest queue:NSOperationQueue.mainQueue
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
         {
             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
             if([httpResponse respondsToSelector:@selector(allHeaderFields)])
             {
                 if(httpResponse.statusCode != 200)
                     return;
                 
                 NSDictionary *metaData = [httpResponse allHeaderFields];
                 NSString *lastModifiedString = [metaData objectForKey:@"Last-Modified"];
                 
                 NSDateFormatter *df = [[NSDateFormatter alloc] init];
                 df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
                 df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
                 df.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
                 
                 NSDate *lastModified = [df dateFromString:lastModifiedString];
                 
                 if(lastModified == nil || ![lastModified isEqualToDate:feed.lastUpdated])
                 {
                     feed.lastUpdated = lastModified;
                     [feed.managedObjectContext save:nil];
                     [self updatePodcastFeed:feed];
                 }
             }
         }];
    }
}

- (void)updatePodcastFeed:(Feed*)feed
{
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:feed.url]];
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if(error)
             return;
         
         BOOL firstLoad = (self.episodes.count == 0);
         
         NSDictionary *RSS = [XMLReader dictionaryForXMLData:data];
         
         NSArray *episodes = [[[RSS objectForKey:@"rss"] objectForKey:@"channel"] objectForKey:@"item"];
         
         for(NSDictionary *epiDic in episodes)
         {
             int number = 0;
             NSString *title = @"";
             
             if([[epiDic objectForKey:@"title"] objectForKey:@"text"])
             {
                 NSString *text = [[[epiDic objectForKey:@"title"] objectForKey:@"text"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                 
                 if([text hasPrefix:@"Leo Laporte - The Tech Guy "])
                 {
                     NSError *error;
                     NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Leo Laporte - The Tech Guy (\\d+)" options:NSRegularExpressionCaseInsensitive error:&error];
                     
                     if(!error)
                     {
                         NSTextCheckingResult *results = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
                         number = [[text substringWithRange:[results rangeAtIndex:1]] intValue];
                         title  = [NSString stringWithFormat:@"Episode #%d", number];
                     }
                     else
                     {
                         number = 0;
                         title  = @"";
                     }
                 }
                 else
                 {
                     NSError *error;
                     NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".* (\\d+) ?: (.*)" options:NSRegularExpressionCaseInsensitive error:&error];
                     
                     if(!error)
                     {
                         NSTextCheckingResult *results = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
                         number = [[text substringWithRange:[results rangeAtIndex:1]] intValue];
                         title  = [text substringWithRange:[results rangeAtIndex:2]];
                     }
                     else
                     {
                         number = 0;
                         title  = @"";
                     }
                 }
             }
             
             NSString *desc = [[[epiDic objectForKey:@"itunes:subtitle"] objectForKey:@"text"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
             desc = [desc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
             
             NSString *pubDateString = [[epiDic objectForKey:@"pubDate"] objectForKey:@"text"];
             NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
             [dateFormat setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
             NSDate *published = [dateFormat dateFromString:pubDateString];
             
             NSString *durationString = [[[epiDic objectForKey:@"itunes:duration"] objectForKey:@"text"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
             NSArray *durationArray = [[[durationString componentsSeparatedByString:@":"] reverseObjectEnumerator] allObjects];
             int duration = 0;
             for(int i = 0; i < durationArray.count; i++)
                 duration += [[durationArray objectAtIndex:i] intValue]*pow(60, i);
             
             NSString *summary = [[epiDic objectForKey:@"description"] objectForKey:@"text"];
             NSString *guests;
             if(summary)
             {
                 NSRegularExpression *guestRegex = [NSRegularExpression regularExpressionWithPattern:@"<p><b>Guests?:</b> (.*?)</p>" options:NSRegularExpressionCaseInsensitive error:NULL];
                 NSTextCheckingResult *guestResults = [guestRegex firstMatchInString:summary options:0 range:NSMakeRange(0, [summary length])];
                 
                 if(guestResults.numberOfRanges > 0)
                     guests = [summary substringWithRange:[guestResults rangeAtIndex:1]];
                 
                 if(!guests)
                 {
                     NSRegularExpression *guestRegex = [NSRegularExpression regularExpressionWithPattern:@"<p><b>Hosts?:</b> (.*?)</p>" options:NSRegularExpressionCaseInsensitive error:NULL];
                     NSTextCheckingResult *guestResults = [guestRegex firstMatchInString:summary options:0 range:NSMakeRange(0, [summary length])];
                     
                     if(guestResults.numberOfRanges > 0)
                         guests = [summary substringWithRange:[guestResults rangeAtIndex:1]];
                 }
                 
                 if(!guests)
                     guests = self.hosts;
                 
                 if(!guests)
                     guests = @"";
                 
                 NSRange r;
                 while((r = [guests rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
                     guests = [guests stringByReplacingCharactersInRange:r withString:@""];
                 
                 //guests = [guests stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
             }
             
             NSString *posterURL = [NSString stringWithFormat:@"http://twit.tv/files/imagecache/slideshow-slide/%@%.4d.jpg", self.titleAcronym.lowercaseString, number];
             
             NSString *enclosureURL = [[epiDic objectForKey:@"enclosure"] objectForKey:@"url"];
             //NSString *enclosureType = [[epiDic objectForKey:@"enclosure"] objectForKey:@"type"];
             NSString *website = [[epiDic objectForKey:@"comments"] objectForKey:@"text"];
             
             
             Episode *episode = nil;
             
             NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title == %@ && number == %d", title, number];
             NSSet *sameEpisode = [self.episodes filteredSetUsingPredicate:predicate];
             
             if(sameEpisode.count > 0)
             {
                 episode = sameEpisode.anyObject;
             }
             else
             {
                 if(self.episodes.count >= MAX_EPISODES)
                 {
                     NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"published" ascending:NO];
                     NSArray *descriptors = [NSArray arrayWithObject:descriptor];
                     NSArray *sortedEpisodes = [self.episodes sortedArrayUsingDescriptors:descriptors];
                     Episode *oldestEpisode = sortedEpisodes.lastObject;
                     
                     if([published laterDate:oldestEpisode.published] == oldestEpisode.published)
                     {
                         continue;
                     }
                     else
                     {
                         [self removeEpisodesObject:oldestEpisode];
                     }
                 }
                 
                 NSManagedObjectContext *context = self.managedObjectContext;
                 episode = [context insertEntity:@"Episode"];
                 episode.title = title;
                 episode.desc = desc;
                 episode.duration = duration;
                 episode.guests = guests;
                 episode.website = website;
                 episode.published = published;
                 episode.number = number;
                 episode.watched = firstLoad;
                 
                 Poster *poster = [context insertEntity:@"Poster"];
                 poster.url = posterURL;
                 episode.poster = poster;
                 
                 [self addEpisodesObject:episode];
             }
             
             
             NSPredicate *pred = [NSPredicate predicateWithFormat:@"quality == %d", feed.quality];
             NSSet *enclosures = [episode.enclosures filteredSetUsingPredicate:pred];
             
             NSManagedObjectContext *context = self.managedObjectContext;
             Enclosure *enclosure = (enclosures.count == 0) ? [context insertEntity:@"Enclosure"] : enclosures.anyObject;
             enclosure.url = enclosureURL;
             enclosure.title = feed.title;
             enclosure.subtitle = feed.subtitle;
             enclosure.quality = feed.quality;
             enclosure.type = feed.type;
             [episode addEnclosuresObject:enclosure];
             
             [context save:nil];
         }
     }];
}

@end
