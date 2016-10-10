﻿SuperStrict
Import "game.newsagency.base.bmx"
Import "game.newsagency.sports.soccer.bmx"

GetNewsAgency().AddNewsProvider( new TNewsAgencyNewsProvider_Weather )
GetNewsAgency().AddNewsProvider( TNewsAgencyNewsProvider_Sport.GetInstance() )



'=== CREATE SPORTS ===
'SOCCER
Global sportSoccer:TNewsEventSport_Soccer = New TNewsEventSport_Soccer
GetNewsEventSportCollection().Add(sportSoccer)


'EventManager.registerListenerFunction( "Sport.StartPlayoffs", onStartPlayoffs )
'EventManager.registerListenerFunction( "Sport.FinishPlayoffs", onFinishPlayoffs )
'EventManager.registerListenerFunction( "SportLeague.StartSeasonPart", onStartSeasonPart )
'EventManager.registerListenerFunction( "SportLeague.FinishSeasonPart", onFinishSeasonPart )
'EventManager.registerListenerFunction( "SportLeague.FinishMatchGroup", onFinishMatchGroup )


Function onStartPlayoffs:Int(event:TEventBase)

	Local sport:TNewsEventSport = TNewsEventSport(event.GetSender())
	Local time:Long = event.GetData().GetLong("time", -1)
	If Not sport Or Not sport.playoffSeasons Then Return False
	Print "onStartPlayoffs : "+sport.name
Return False
	Print "  " + "-------------------------"
	For Local i:Int = 0 Until sport.playoffSeasons.length
		Print "  Leaderboard Playoffs League "+(i+1)+"->"+(i+2)
		Print "  " + LSet("Score", 8) + LSet("Team", 40)

		Local season:TNewsEventSportSeason = sport.playoffSeasons[i]
If Not season Then Print "season null"
		Local seasonData:TNewsEventSportSeasonData = sport.playoffSeasons[i].data
If Not seasonData Then Print "seasonData null"

		For Local rank:TNewsEventSportLeagueRank = EachIn sport.playoffSeasons[i].data.GetLeaderboard( time )
			Print "  " + LSet(rank.score, 8) + LSet(rank.team.nameInitials, 5)+" "+LSet(rank.team.name, 40)
		Next
		Print "  " + "-------------------------"
	Next
End Function

Function onFinishPlayoffs:Int(event:TEventBase)
	Local sport:TNewsEventSport = TNewsEventSport(event.GetSender())
	Print "onFinishPlayoffs: "+sport.name
End Function


Function onStartSeasonPart:Int(event:TEventBase)
	Local league:TNewsEventSportLeague = TNewsEventSportLeague(event.GetSender())
	If sportSoccer.ContainsLeague(league)
		Local time:Double = event.GetData().GetDouble("time")

		if GetWorldTime().getDay(time) < GetWorldTime().GetStartDay() then return False

		print "onStartSeasonPart: "+league.GetCurrentSeason().part+"/"+league.GetCurrentSeason().partMax+"  "+league.name
	EndIf
End Function

Function onFinishSeasonPart:Int(event:TEventBase)
	Local league:TNewsEventSportLeague = TNewsEventSportLeague(event.GetSender())

	If sportSoccer.ContainsLeague(league)
		Local time:Double = event.GetData().GetDouble("time")

		if GetWorldTime().getDay(time) < GetWorldTime().GetStartDay() then return False

		If league.GetCurrentSeason().part = league.GetCurrentSeason().partMax
			Print "FINISH SEASON: "+league.name +"   day:"+GetWorldTime().GetDay(time)
		Else
'			print "FINISH SEASON PART: "+league.seasonPart+"/"+league.seasonPartMax+"  "+league.name
		EndIf

		'only final leaderboard
		If league.GetCurrentSeason().part = league.GetCurrentSeason().partMax
			Print "  " + "-------------------------"
			Print "  Leaderboard "+league.name+":"
			Print "  " + LSet("Score", 8) + LSet("Team", 40)
			For Local rank:TNewsEventSportLeagueRank = EachIn league.GetLeaderboard()
				Print "  " + LSet(rank.score, 8) + LSet(rank.team.nameInitials, 5)+" "+LSet(rank.team.name, 40)
			Next
			Print "  " + "-------------------------"
		EndIf
	EndIf
End Function


'==== OPTION 2: wait for match groups ====
Function onFinishMatchGroup:Int(event:TEventBase)
	Local league:TNewsEventSportLeague = TNewsEventSportLeague(event.GetSender())
	Local matches:TNewsEventSportMatch[] = TNewsEventSportMatch[](event.GetData().Get("matches"))
	If Not matches Or matches.length = 0 Or Not league Then Return False
	'ignore games of the past
	Local time:Long = event.GetData().GetLong("time")
	if GetWorldTime().getDay(time) < GetWorldTime().GetStartDay() then return False

	Print league.name+"  MatchGroup  gameDay="+RSet(GetWorldTime().GetDaysRun(time),2)+"  " + GetWorldTime().GetFormattedTime(time)

	Local weekday:String = GetWorldTime().GetDayName( GetWorldTime().GetWeekday( GetWorldTime().GetOnDay(matches[0].GetMatchTime()) ) )
	For Local match:TNewsEventSportMatch = EachIn matches
'RONNY
		Print "    Match: "+GetWorldTime().GetFormattedDate(match.GetMatchTime())+"  "+LSet(weekday,10) + match.teams[0].nameInitials + " " + match.points[0]+" : " + match.points[1] + " " + match.teams[1].nameInitials
	Next
End Function













Type TNewsAgencyNewsProvider_Sport extends TNewsAgencyNewsProvider
	Global _eventListeners:TLink[]
	Global _instance:TNewsAgencyNewsProvider_Sport


	Method New()
		'=== REGISTER EVENTS ===
		EventManager.unregisterListenersByLinks(_eventListeners)
		_eventListeners = new TLink[0]

		_eventListeners :+ [EventManager.registerListenerFunction( "SportLeague.RunMatch", onRunMatch )]
	End Method


	Function GetInstance:TNewsAgencyNewsProvider_Sport()
		if not _instance then _instance = new TNewsAgencyNewsProvider_Sport
		return _instance
	End Function


	'==== OPTION 1: directly wait for matches ====
	Function onRunMatch:Int(event:TEventBase)
		Local league:TNewsEventSportLeague = TNewsEventSportLeague(event.GetSender())
		Local match:TNewsEventSportMatch = TNewsEventSportMatch(event.GetData().Get("match"))
		Local sport:TNewsEventSport = GetNewsEventSportCollection().GetByGUID( league._sportGUID )
		Local season:TNewsEventSportSeason = league.GetCurrentSeason()

		If Not match Or Not league or not sport Then Return False
		'ignore games of the past
		if GetWorldTime().getDay(match.GetMatchTime()) < GetWorldTime().GetStartDay() then return False

		'ignore leagues >= 3 ("Regionalliga")
		if league._leaguesIndex > 2 then return False
		
		Local weekday:String = GetWorldTime().GetDayName( GetWorldTime().GetWeekday( GetWorldTime().GetOnDay(match.GetMatchTime()) ) )


		Local NewsEvent:TNewsEvent = new TNewsEvent
		local localizeTitle:TLocalizedString = new TLocalizedString
		local localizeDescription:TLocalizedString = new TLocalizedString
		'quality gets lower the higher the league index (less important)
		Local quality:Float = 0.01 * randRange(50,60) * 0.9 ^ league._leaguesIndex
		Local price:Float = 1.0 + 0.01 * randRange(-5,10) * 1.05 ^ league._leaguesIndex
		

		localizeTitle.Set(Getlocale("SPORT_"+sport.name) +" ["+league.nameShort+"]: " +match.GetReportShort())
		if season and season.seasonType = TNewsEventSportSeason.SEASONTYPE_PLAYOFF
			localizeDescription.Set("Relegationsspiel:~n"+match.GetReport())
		elseif not season
			localizeDescription.Set("unbekannt:~n"+match.GetReport())
		else
			localizeDescription.Set(match.GetReport())
		endif
		NewsEvent.Init("", localizeTitle, localizeDescription, TVTNewsGenre.SPORT, quality, null, TVTNewsType.InitialNewsByInGameEvent)
		NewsEvent.SetModifier("price", price)
		'3.0 means it reaches topicality of 0 at ~5 hours after creation.
		NewsEvent.SetModifier("topicality::age", 3.0)
		NewsEvent.AddKeyword("SPORT")
		'let the game finish first
		NewsEvent.happenedTime = GetWorldTime().GetTimeGone() + 60 * (90 + RandRange(0,10))

		NewsEvent.eventDuration = 5*3600 'only for 8 hours
		NewsEvent.SetFlag(TVTNewsFlag.UNIQUE_EVENT, True) 'one time event
		GetNewsEventCollection().AddOneTimeEvent(NewsEvent)

		GetInstance().AddNewNewsEvent(newsEvent)
		print "  Match: gameday="+RSet(GetWorldTime().GetDaysRun(),2)+"  "+ GetWorldTime().GetFormattedDate(NewsEvent.happenedTime)+"  "+Lset(weekday,10) + " " + match.GetReportshort() + "  " + match.GetReport()
	End Function



	Method Update:int()
		_instance = self
		'nothing for now, sports updates are handled by TGame
	End Method
End Type




Type TNewsAgencyNewsProvider_Weather extends TNewsAgencyNewsProvider
	'=== WEATHER HANDLING ===
	'time of last weather event/news
	Field weatherUpdateTime:Double = 0
	'announce new weather every x-y minutes
	Field weatherUpdateTimeInterval:int[] = [270, 300]
	Field weatherType:int = 0

	Global _eventListeners:TLink[]


	Method Initialize:int()
		Super.Initialize()
		
		weatherUpdateTime = 0
		weatherUpdateTimeInterval = [270, 300]
		weatherType = 0

		'=== REGISTER EVENTS ===
		EventManager.unregisterListenersByLinks(_eventListeners)
		_eventListeners = new TLink[0]
	End Method


	Method Update:int()
		If weatherUpdateTime < GetWorldTime().GetTimeGone()
			weatherUpdateTime = GetWorldTime().GetTimeGone() + 60 * randRange(weatherUpdateTimeInterval[0], weatherUpdateTimeInterval[1])
			'limit weather forecasts to get created between xx:10-xx:40
			'to avoid forecasts created just before the news show
			If GetWorldTime().GetDayMinute(weatherUpdateTime) > 40
				local newTime:Long = GetWorldTime().MakeTime(0, GetWorldtime().GetDay(weatherUpdateTime), GetWorldtime().GetDayHour(weatherUpdateTime), RandRange(10, 40), 0)
				weatherUpdateTime = newTime
			EndIf
			
			local newsEvent:TNewsEvent = GetWeatherNewsEvent()
			If newsEvent
				?debug
				Print "[NEWSAGENCY | LOCAL] UpdateWeather: added weather news title="+newsEvent.GetTitle()+", day="+GetWorldTime().getDay(newsEvent.happenedtime)+", time="+GetWorldTime().GetFormattedTime(newsEvent.happenedtime)
				?
			EndIf
			
			AddNewNewsEvent(newsEvent)
'				announceNewsEvent(newsEvent, GetWorldTime().GetTimeGone())
		EndIf
	End Method



	Method GetWeatherNewsEvent:TNewsEvent()
		'if we want to have a forecast for a fixed time
		'(overlapping with other forecasts!)
		'-> forecast for 6 hours
		'   (after ~5 hours the next forecast gets created)
		local forecastHours:int = 6
		'if we want to have a forecast till next update
		'local forecastHours:int = ceil((weatherUpdateTime - GetWorldTime().GetTimeGone()) / 3600.0)

		'quality and price are nearly the same everytime
		Local quality:Float = 0.01 * randRange(50,60)
		Local price:Float = 1.0 + 0.01 * randRange(-5,10)
		'append 1 hour to both: forecast is done eg. at 7:30 - so it
		'cannot be a weatherforecast for 7-10 but for 8-11
		local beginHour:int = (GetWorldTime().GetDayHour()+1) mod 24
		local endHour:int = (GetWorldTime().GetDayHour(GetWorldTime().GetTimeGone() + forecastHours * 3600)+1) mod 24
		Local description:string = ""
		local title:string = GetLocale("WEATHER_FORECAST_FOR_X_TILL_Y").replace("%BEGINHOUR%", beginHour).replace("%ENDHOUR%", endHour)
		local weather:TWorldWeatherEntry
		'states
		local isRaining:int = 0
		local isSnowing:int = 0
		local isBelowZero:int = 0
		local isCloudy:int = 0
		local isClear:int = 0
		local isPartiallyCloudy:int = 0
		local isNight:int = 0
		local isDay:int = 0
		local becameNight:int = False
		local becameDay:int = False
		local sunHours:int = 0
		local sunAverage:float = 0.0
		local tempMin:int = 1000, tempMax:int = -1000
		local windMin:Float = 1000, windMax:Float = -1000

		'fetch next weather
		local upcomingWeather:TWorldWeatherEntry[forecastHours]
		For local i:int = 0 until forecastHours
			upcomingWeather[i] = GetWorld().Weather.GetUpcomingWeather(i+1)
		Next


		'check for specific states
		For weather = eachin upcomingWeather
			if GetWorldTime().IsNight(weather._time)
				if isDay then becameNight = True
				isNight = True
			else
				if isNight then becameDay = True
				isDay = True
			endif

			tempMin = Min(tempMin, weather.GetTemperature())
			tempMax = Max(tempMax, weather.GetTemperature())

			windMin = Min(windMin, Abs(weather.GetWindVelocity() * 20))
			windMax = Max(windMax, Abs(weather.GetWindVelocity() * 20))

			if weather.GetTemperature() < 0 then isBelowZero = True
			if weather.IsRaining() and weather.GetTemperature() >= 0 then isRaining = True
			if weather.GetTemperature() < 0 and weather.IsRaining() then isSnowing = True

			if weather.GetWorldWeather() = TWorldWeather.WEATHER_CLEAR
				isClear = True
			else
				isCloudy = True
			endif

			if weather.IsSunVisible() then sunHours :+1
		Next
		if isCloudy and isClear
			isPartiallyCloudy = True
			isCloudy = False
			isClear = False
		endif
		sunAverage = float(sunHours)/float(forecastHours)



		'construct text
		description = ""
		
		if isPartiallyCloudy
			description :+ GetRandomLocale("SKY_IS_PARTIALLY_CLOUDY")+" "
		elseif isCloudy
			description :+ GetRandomLocale("SKY_IS_OVERCAST")+" "
		elseif isClear
			description :+ GetRandomLocale("SKY_IS_WITHOUT_CLOUDS")+" "
		endif

		if isDay or becameDay
			if becameDay then description :+ GetRandomLocale("IN_THE_LATER_HOURS")+": "

			if sunAverage = 1.0 and not isCloudy and not becameDay
				if not isNight then description :+ GetRandomLocale("SUN_SHINES_WHOLE_TIME")+" "
			elseif sunAverage > 0.5
				description :+ GetRandomLocale("SUN_WINS_AGAINST_CLOUDS")+" "
			elseif sunAverage > 0
				description :+ GetRandomLocale("SUN_IS_SHINING_SOMETIMES")+" "
			else
				description :+ GetRandomLocale("SUN_IS_NOT_SHINING")+" "
			endif
		endif

		if isRaining and isSnowing
			description :+ GetRandomLocale("RAIN_AND_SNOW_ALTERNATE")+" "
		elseif isRaining
			description :+ GetRandomLocale("RAIN_IS_POSSIBLE")+" "
		elseif isSnowing
			description :+ GetRandomLocale("SNOW_IS_FALLING")+" "
		endif

		local temperatureText:string
		if tempMin <> tempMax
			temperatureText = GetRandomLocale("TEMPERATURES_ARE_BETWEEN_X_AND_Y")
		else
			temperatureText = GetRandomLocale("TEMPERATURE_IS_CONSTANT_AT_X")
		endif


		local weatherText:string
		if windMin < 2 and windMax < 2
			weatherText = GetRandomLocale("NEARLY_NO_WIND")
		elseif windMin <> windMax
			if windMin > 0 and windMax > 10
				if windMin > 20 and windMax > 35
					weatherText = GetRandomLocale("STORMY_WINDS_OF_UP_TO_X")
				else
					weatherText = GetRandomLocale("SLOW_WIND_WITH_X_AND_GUST_OF_WIND_WITH_Y")
				endif
			else
				weatherText = GetRandomLocale("WIND_VELOCITIES_ARE_BETWEEN_X_AND_Y")
			endif
		else
			weatherText = GetRandomLocale("WIND_VELOCITY_IS_CONSTANT_AT_X")
		endif

		if temperatureText <> "" then description :+ " " + temperatureText.replace("%TEMPERATURE%", tempMin).replace("%MINTEMPERATURE%", tempMin).replace("%MAXTEMPERATURE%", tempMax)
		if weatherText <> ""  then description :+ " " + weatherText.replace("%MINWINDVELOCITY%", MathHelper.NumberToString(windMin, 2, True)).replace("%MAXWINDVELOCITY%", MathHelper.NumberToString(windMax, 2, True))


		local localizeTitle:TLocalizedString = new TLocalizedString
		localizeTitle.Set(title) 'use default lang
		local localizeDescription:TLocalizedString = new TLocalizedString
		localizeDescription.Set(description) 'use default lang

		Local NewsEvent:TNewsEvent = new TNewsEvent.Init("", localizeTitle, localizeDescription, TVTNewsGenre.CURRENTAFFAIRS, quality, null, TVTNewsType.InitialNewsByInGameEvent)
		NewsEvent.SetModifier("price", price)
		'after 20 hours a news topicality is 0 - so accelerating it by
		'2.0 means it reaches topicality of 0 at 8 hours after creation.
		'This is 2 hours after the next forecast (a bit overlapping)
		NewsEvent.SetModifier("topicality::age", 2.0)

		NewsEvent.AddKeyword("WEATHERFORECAST")

		'TODO
		'add weather->audience effects
		'rain = more audience
		'sun = less audience
		'...
		'-> instead of using "effects" for weather forecast, we just
		'emit gameevents (world-time-depending!) to enable the effect
		'at the forecast start and _NOT_ at the newsevent creation time
		'
		'maybe just connect weather and potential audience directly
		'instead of using the newsevents

		NewsEvent.eventDuration = 8*3600 'only for 8 hours
		NewsEvent.SetFlag(TVTNewsFlag.SEND_IMMEDIATELY, True)
		NewsEvent.SetFlag(TVTNewsFlag.UNIQUE_EVENT, True) 'one time event

		GetNewsEventCollection().AddOneTimeEvent(NewsEvent)

		Return NewsEvent
	End Method
End Type


