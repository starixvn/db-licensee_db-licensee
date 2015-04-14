USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_Monitor_BetlistSel_New]                
 @LicenseeID INT,
 @UserID	 INT,	
 @bettype VARCHAR(50) = NULL,                
 @LicenseeType VARCHAR(100) = NULL,                
 @Currency VARCHAR(200) = NULL ,                
 @SpecialLevel VARCHAR(200) = NULL,                
 @transid BIGINT = 0,                
 @LimitRowCount INT = 10,                 
 @SportID INT = 0,                
 @LeagueID INT = 0,                
 @Matchid INT = 0,                
 @MinStake MONEY = 0,                
 @MaxStake MONEY = 0,                
 @Liveindicator INT = 0 ,
 @includebetfrom BIT=1,
 @betfrom	TINYINT=0,
 @BaseCurrency VARCHAR(10) ='USD',
 @debug bit = 0                
AS                 
                
/*                 
 Created : Scott                
 Task: LRF Monitor lastest bets list(all bettypes and all sports) with filter by League and Sport                
 Date: 2013-04-18                
 DB: DB052.BODB02                
 Original: [Lrf_Monitor_BetlistSel]                
 Revision:                
     - 20130618@Jim:  Restrict permission of Licensee Users by currency 
	- 20130806@Jim:  Add betting platform to Last bets monitoring 	
	- 20140620@Florent: offer Sporting Solution (36 new bettypes)
	- 20141021@Florent: Apply for the change in Sporting Solution structure (#24478)
	- 20141120@Jim: expand data range for @transid param to covert big datatype
	- 20150128@Jim: base on GBP
 Parameter's Explanation:                
  - @bettypes:                 
   + HDP: 1,7, 1303 (Set Handicap)                
   + Others: NOT IN 1,3,7,8, 1303, 1306                
   + OU: 3,8, 1306 (Match Total Games Over/Under)                
   + ALL: <=19000                
  - @transid: lastest transid                 
  - @LimitRowCount: max record return (10,20,30)                
  - @SportID = 999  -> Parlay and System Parlay       
  - @Liveindicator ( 0 : non live, 1 : live , 2 : mix non live & live)   
  - @includebetfrom: 1: show column betfrom, 0: hide
  - @betfrom: 0: All
			  1: WEB (d)
		      2: WAP (m)		
              3: SMARTPHONE (sl) 
			  4: Other (not in  (d,m,s,l))
 Excecute sample :                
                
[Lrf_Monitor_BetlistSel_New]                 
  @LicenseeID = 14,                
  @bettype='HDP',                
  @LicenseeType='Normal',                
  @Currency='1,2,3,4,5,6,7,8,9,10',                
  @SpecialLevel='0,1,2,3,4,5,6,7,8,9',                
  @transid=0,                
  @LimitRowCount=10,                
  @SportID=1,                
  @LeagueID=3,                
  @Matchid=3874470,                
  @MinStake=100,                
  @Liveindicator=0                
                
*/             
              
DECLARE @SQL VARCHAR(8000)                
DECLARE @ORDERBY VARCHAR(1000)                
SELECT @SQL='SET NOCOUNT ON '                
              
IF (@Currency IS NULL OR @Currency = '' )                
 SET @Currency = 'ALL'                 
IF (@LicenseeType IS NULL OR @LicenseeType = '' )                
 SET @LicenseeType = 'ALL'                 
IF (@SpecialLevel IS NULL OR @SpecialLevel = '' )                
 SET @SpecialLevel = 'ALL'                   
IF @MinStake IS NULL              
 SET @MinStake = 0              
IF @MaxStake IS NULL              
 SET @MaxStake = 0              

IF (@SportID > 0 AND @SportID <> 999)
BEGIN

	SET @SQL = 
		'DECLARE @match TABLE(matchid int primary key)' + char(13) +
		'INSERT INTO @match' + char(13) +
			'SELECT matchid' + char(13) +
			'FROM dbo.match (NOLOCK)' + char(13) +
			'WHERE sporttype = ' + convert(varchar(10),@SportID) + ' AND eventstatus = ''running''' + char(13) +
				CASE 
					WHEN @LeagueID > 0 THEN 'AND leagueid = ' + convert(varchar(10),@LeagueID)
					ELSE ''
				END + char(13) +
				CASE 
					WHEN @Matchid > 0 THEN 'AND matchid = ' + convert(varchar(10),@Matchid)
					ELSE ''
				END + char(13) +
			'UNION ALL' + char(13) +
			'SELECT o.orid' + char(13) +
			'FROM (SELECT orid,leagueid FROM dbo.outright (NOLOCK) WHERE oddsstatus = ''running'') as o ' + char(13) +
				'CROSS APPLY (SELECT l.leagueid FROM dbo.league l (NOLOCK) WHERE o.leagueid = l.leagueid AND l.sporttype = ' + convert(varchar(10),@SportID) + ') as l2' + char(13) +
			'WHERE (1=1)' + char(13) +
				CASE 
					WHEN @LeagueID > 0 THEN 'AND o.leagueid = ' + convert(varchar(10),@LeagueID)
					ELSE ''
				END + char(13) +
				CASE 
					WHEN @Matchid > 0 THEN 'AND o.orid = ' + convert(varchar(10),@Matchid)
					ELSE ''
				END + char(13)

END
              
SELECT @SQL = @SQL + 'SELECT TOP ('+CONVERT(VARCHAR(10),@LimitRowCount)+')'+CHAR(13)+                
  '0 AS sporttype,'+CHAR(13)+                
  'b.matchid,'+CHAR(13)+                
  '0 AS leagueid,'+CHAR(13)+                
  'b.Username,'+CHAR(13)+                
  'SUBSTRING(b.username2, CHARINDEX(''$'', b.username2) + 1,LEN(b.username2) - CHARINDEX(''$'',b.username2)) AS nickname,'+CHAR(13)+                
  'b.bettype,'+CHAR(13)+                
  'b.transid,'+CHAR(13)+                
  'b.refno,'+CHAR(13)+                
  'b.transdate,'+char(13)+                    
  ''''' AS matchcode,'+CHAR(13)+                
  '0 AS homeid,'+CHAR(13)+                
  '0 AS awayid,'+CHAR(13)+                
  ''''' AS race,'+CHAR(13)+                
  'b.betid,'+CHAR(13)+                
  'b.livehomescore,'+CHAR(13)+                
  'b.liveawayscore,'+CHAR(13)+                
  --'CONVERT(INT,b.liveindicator) AS LiveIndicator,'+CHAR(13)+                
  'b.liveindicator AS LiveIndicator,'+CHAR(13)+
  'b.hdp1,'+CHAR(13)+                
  'b.hdp2,'+CHAR(13)+                
  'b.odds,'+CHAR(13)+                
	CASE 
		WHEN @BaseCurrency = 'USD' THEN 'b.actual_stake * ex.USD actual_stakeUSD,'
		WHEN @BaseCurrency = 'EUR' THEN 'b.actual_stake * ex.EUR actual_stakeEUR,'
		WHEN @BaseCurrency = 'GBP' THEN 'b.actual_stake * ex.GBP actual_stakeGBP,'
		ELSE 'b.actual_stake ' + 'actual_stake' + @BaseCurrency + ',' 
	END + CHAR(13) +
	CASE 
		WHEN @BaseCurrency = 'USD' THEN 'b.stake * ex.USD StakeUSD,'
		WHEN @BaseCurrency = 'EUR' THEN 'b.stake * ex.EUR StakeEUR,'
		WHEN @BaseCurrency = 'GBP' THEN 'b.stake * ex.GBP StakeGBP,'
		ELSE 'b.stake ' + 'Stake' + @BaseCurrency + ',' 
	END + CHAR(13) +
	CASE WHEN 
			@includebetfrom=1 THEN 'betfrom,'
			ELSE ''
			END +char(13)+
  '''running'' as status,'+CHAR(13)+                
  'b.betteam,'+CHAR(13)+                    
  'CONVERT(BIT,0) AS isNeutral,'+CHAR(13)+                   
  'b.OddsType,'+CHAR(13)+                
  'b.currency as currencyid,'+CHAR(13)+                
  ''''' as currencyname,'+CHAR(13)+                
  'b.SpecialLevel' +CHAR(13)+                
  'FROM bettrans_lrf_betRunning b WITH(NOLOCK)  '+CHAR(13) +   
  'INNER JOIN Lrf_f_GetExchangeDaily(CONVERT(VARCHAR(10), getdate(), 111),CONVERT(VARCHAR(10), getdate(), 111))  ex on ex.exchangeid = b.currency ' + CHAR(13) +             
  'INNER JOIN bodb_licensee.dbo.CurrencyUser cr WITH (NOLOCK) ON b.LicenseeID=cr.LicenseeID AND b.Currency=cr.CurrencyID'+char(13)+
  CASE               
   WHEN @SportID>0 and @Sportid <> 999 THEN 'INNER JOIN @Match m on b.matchid = m.matchid '               
   ELSE ' '               
  END  +CHAR(13)+               
   'WHERE b.LicenseeID='+convert(varchar(10),@LicenseeID)+ ' '  +CHAR(13)+  
   'AND cr.isActive=1'+char(13)+
   'AND cr.UsrID='+convert(varchar(20),@UserID)+''+char(13)+
   'AND cr.SystemID=1'+char(13)+
   'AND Transid >'+convert(varchar(20),@transid)+'  '+CHAR(13)+              
    'AND Statusid = 0   '+CHAR(13)+
CASE WHEN @betfrom=1 THEN 'AND betfrom=''d'''
		 WHEN @betfrom=2 THEN 'AND betfrom=''m'''
		 WHEN @betfrom=3 THEN 'AND betfrom IN (''s'',''l'')'
		 WHEN @betfrom=4 THEN 'AND betfrom NOT IN (''d'',''m'',''s'',''l'')'
		 ELSE ''
	END+CHAR(13)+                  
	CASE 
		WHEN @BaseCurrency = 'USD' THEN
										CASE               
											WHEN @MinStake=0 AND @MaxStake>0 THEN 'AND b.stake * ex.USD  <= '+convert(varchar(20),@MaxStake)               
											WHEN @MinStake>0 AND @MaxStake=0 THEN 'AND b.stake * ex.USD  >= '+convert(varchar(20),@MinStake)               
											WHEN @MinStake>0 AND @MaxStake>0 THEN 'AND b.stake * ex.USD  between '+convert(varchar(20),@MinStake) +' and ' +convert(varchar(20),@MaxStake)               
										ELSE ' ' END  
		
		
		WHEN @BaseCurrency = 'EUR' THEN 
										CASE               
											WHEN @MinStake=0 AND @MaxStake>0 THEN 'AND b.stake * ex.EUR  <= '+convert(varchar(20),@MaxStake)               
											WHEN @MinStake>0 AND @MaxStake=0 THEN 'AND b.stake * ex.EUR  >= '+convert(varchar(20),@MinStake)               
											WHEN @MinStake>0 AND @MaxStake>0 THEN 'AND b.stake * ex.EUR  between '+convert(varchar(20),@MinStake) +' and ' +convert(varchar(20),@MaxStake)               
										ELSE ' ' END 
		
		WHEN @BaseCurrency = 'GBP' THEN 
										CASE               
											WHEN @MinStake=0 AND @MaxStake>0 THEN 'AND b.stake * ex.GBP  <= '+convert(varchar(20),@MaxStake)               
											WHEN @MinStake>0 AND @MaxStake=0 THEN 'AND b.stake * ex.GBP  >= '+convert(varchar(20),@MinStake)               
											WHEN @MinStake>0 AND @MaxStake>0 THEN 'AND b.stake * ex.GBP  between '+convert(varchar(20),@MinStake) +' and ' +convert(varchar(20),@MaxStake)               
										ELSE ' ' END 
		ELSE 
										CASE               
											WHEN @MinStake=0 AND @MaxStake>0 THEN 'AND b.stake  <= '+convert(varchar(20),@MaxStake)               
											WHEN @MinStake>0 AND @MaxStake=0 THEN 'AND b.stake  >= '+convert(varchar(20),@MinStake)               
											WHEN @MinStake>0 AND @MaxStake>0 THEN 'AND b.stake  between '+convert(varchar(20),@MinStake) +' and ' +convert(varchar(20),@MaxStake)               
										ELSE ' ' END 
	END + CHAR(13) +      
  CASE WHEN @Currency <> 'ALL' THEN 'AND currency in ('+@Currency+') 'ELSE ' ' END + CHAR(13)+              
  CASE WHEN @LicenseeType <> 'ALL' THEN 'AND [Description] = '''+@LicenseeType+'''' ELSE ' ' END + CHAR(13)+              
  CASE WHEN @SpecialLevel <> 'ALL' THEN 'AND SpecialLevel IN ('+@SpecialLevel+')' ELSE ' ' END+ CHAR(13)+              
  CASE 
	WHEN @SportID>0 AND @SportID < 999 AND @Liveindicator IN (0,1) THEN 'AND Liveindicator = '+convert(varchar(10),@Liveindicator) 
	WHEN @SportID>0 AND @SportID < 999 AND @Liveindicator = 2 THEN 'AND b.bettype=9 and b.Livehomescore=' + convert(varchar(10),@Liveindicator)
	WHEN @SportID>0 and @Sportid <> 999 and @Liveindicator = 3 THEN'AND ( b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR (b.Bettype BETWEEN 1301 and 1399) )'
	ELSE ' ' END + CHAR(13) +
  CASE 
		WHEN @SportID=0 THEN 
			CASE
				WHEN @Liveindicator = 3 THEN 'AND ( b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR (b.Bettype BETWEEN 1301 and 1399))' 
				WHEN @Liveindicator = 2 THEN 'AND b.bettype=9 and b.Livehomescore=' + convert(varchar(10),@Liveindicator) + ' '
				WHEN @Liveindicator IN (0,1) THEN 
					'AND 
						(
							(Liveindicator=' + convert(varchar(10),@Liveindicator) + 
								' AND 
									(
										(b.bettype < 31 AND b.bettype NOT IN (9,29)) 
										OR b.bettype BETWEEN 121 AND 999
										OR (b.Bettype BETWEEN 1301 and 1399)
									)
							) ' +
							'OR 
							(b.bettype IN (9,29) AND b.Livehomescore=' + convert(varchar(10),@Liveindicator) + ')
						) '
				ELSE ' '
			END
		ELSE ' ' 
	END +CHAR(13)+
  
  CASE                
   WHEN @bettype = 'HDP' AND @SportID<>999 THEN 'AND  b.bettype IN (1,7,1303)  '                
   WHEN @bettype = 'OU' AND @SportID<>999 THEN ' AND b.bettype IN (3,8,178,1306)  '                 
   WHEN @bettype = 'Others' AND @SportID<>999 THEN ' AND b.bettype NOT IN (1,3,7,8,178,1303,1306)  '                
  ELSE ' ' END + CHAR(13)+
  
  CASE @SportID
   WHEN 999 THEN 
	CASE @Liveindicator 
		WHEN 3 THEN 'AND b.bettype IN (9,29) '
		WHEN 2 THEN 'AND b.bettype=9 AND b.Livehomescore=' + convert(varchar(10),@Liveindicator) + ' '
		ELSE 'AND b.bettype IN (9,29) AND b.Livehomescore=' + convert(varchar(10),@Liveindicator) + ' '
	END
   ELSE ''
  END + CHAR(13) +
                
	'ORDER BY transid desc'
                          
IF (@debug = 1)  
 PRINT @sql                
ELSE               
 EXEC(@sql)   

GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [bodbLicenseeNet]  
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [vnteam]  