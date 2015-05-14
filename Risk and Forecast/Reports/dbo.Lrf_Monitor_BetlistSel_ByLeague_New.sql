USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Monitor_BetlistSel_ByLeague_New]    Script Date: 06/19/2013 08:40:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*sp_helpindex bettrans_lrf_betRunning


[Lrf_Monitor_BetlistSel_ByLeague_New]   
  @LicenseeID = 1,  
  @bettype='HDP',  
  @LicenseeType='Normal',  
  @Currency='1,2,3,4,5,6,7,8,9,10',  
  @SpecialLevel='0,1,2,3,4,5,6,7,8,9',  
  @transid=0,  
  @LimitRowCount=10,  
  @SportID=1,  
  @LeagueID=3,  
  @Matchid=3874470,  
  @Stake=0,  
  @MAXstake=1000,  
  @Liveindicator=0 ,
  @debug=0
  
  
  
  
[Lrf_Monitor_BetlistSel_ByLeague_New_bk]   
  @LicenseeID = 1,  
  @bettype='HDP',  
  @LicenseeType='Normal',  
  @Currency='1,2,3,4,5,6,7,8,9,10',  
  @SpecialLevel='0,1,2,3,4,5,6,7,8,9',  
  @transid=0,  
  @LimitRowCount=10,  
  @SportID=1,  
  @LeagueID=3,  
  @Matchid=3874470,  
  @Stake=0,  
  @MAXstake=1000,  
  @Liveindicator=0 

  
  */
  
    
    
ALTER PROCEDURE [dbo].[Lrf_Monitor_BetlistSel_ByLeague_New]  
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
 @Stake MONEY = 0,  
 @MaxStake MONEY = 0,  
 @Liveindicator bit = 0 , 
 @debug bit = 0  
AS  
  
/*   
 Created : Scott  
 Task: LRF Monitor lastest bets list( all bettypes and all sports) with filter by League and Sport  
 Date: 2013-04-01  
 DB: DB052.BODB02  
 Original: [Lrf_Monitor_BetlistSel]  
 Revision:  
   20130618@Jim:  Restrict permission of Licensee Users by currency
 Parameter's Explanation:  
  - @bettypes:   
   + HDP: 1,7  
   + Others: NOT IN 1,3,7,8  
   + OU: 3,8  
   + ALL: <=19000  
  - @transid: lastest transid   
  - @LimitRowCount: max record return (10,20,30)  
  - @SportID = 999  -> Parlay and System Parlay 
  
 Excecute sample :  
  
[Lrf_Monitor_BetlistSel_ByLeague_New]   
  @LicenseeID = 1,  
  @bettype='HDP',  
  @LicenseeType='Normal',  
  @Currency='1,2,3,4,5,6,7,8,9,10',  
  @SpecialLevel='0,1,2,3,4,5,6,7,8,9',  
  @transid=0,  
  @LimitRowCount=10,  
  @SportID=1,  
  @LeagueID=3,  
  @Matchid=3874470,  
  @stake=100,  
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
IF @Stake IS NULL
	SET @Stake = 0
IF @MaxStake IS NULL
	SET @MaxStake = 0

 SELECT @SQL = @SQL +'	SELECT CurrencyID
							,LicenseeID
							,UsrID INTO #Currency 
							FROM  bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
							WHERE  usrID='+convert(varchar(20),@userID)+ char(13)+
							'AND LicenseeID='+convert(varchar(20),@LicenseeID)+ char(13)+
							'AND SystemID=1
							 AND isActive=1'
			+char(13)


IF (@SportID>0 AND @SportID <> 999 )  
BEGIN    
	SELECT @SQL =	'DECLARE @Match TABLE(matchid int primary key) ' +CHAR(13)+ 
					'INSERT INTO @Match ' +CHAR(13)+ 
					'SELECT matchid' +CHAR(13)+ 
					'FROM dbo.match (NOLOCK)'+CHAR(13)+ 
					'WHERE Sporttype = '+convert(varchar(10),@sportid)+ ' ' +CHAR(13)+ 
				CASE WHEN @LeagueID<>0 THEN 'and Leagueid = '+ convert(varchar(10),@LeagueID)  END + ' '+ CHAR(13) + 
				CASE WHEN @Matchid<>0 THEN 'and Matchid = '+ convert(varchar(10),@Matchid)  	END+ ' ' 	+ CHAR(13)	
				
					
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
		'CONVERT(INT,b.liveindicator) AS LiveIndicator,'+CHAR(13)+  
		'b.hdp1,'+CHAR(13)+  
		'b.hdp2,'+CHAR(13)+  
		'b.odds,'+CHAR(13)+  
		'b.actual_stake,'+CHAR(13)+  
		'b.stake,'+CHAR(13)+  
		'''running'' as status,'+CHAR(13)+  
		'b.betteam,'+CHAR(13)+      
		'CONVERT(BIT,0) AS isNeutral,'+CHAR(13)+     
		'b.OddsType,'+CHAR(13)+  
		'b.currency as currencyid,'+CHAR(13)+  
		''''' as currencyname,'+CHAR(13)+  
		'b.SpecialLevel' +CHAR(13)+  
		'FROM bettrans_lrf_betRunning b WITH(NOLOCK,INDEX([IDX_bettrans_lrf_betRunning]))  '+CHAR(13) + 
		'INNER JOIN #Currency c ON b.LicenseeID=c.LicenseeID AND b.Currency=c.CurrencyID'+CHAR(13)+
		CASE 
			WHEN @SportID>0 and @Sportid <> 999 THEN 'INNER JOIN @Match m on b.matchid = m.matchid ' 
			ELSE ' ' 
		END  +CHAR(13)+ 
		'WHERE LicenseeID='+convert(varchar(10),@LicenseeID)+ ' '  +CHAR(13)+
				'AND Transid >='+convert(varchar(10),@transid)+'  '+CHAR(13)+
				'AND Statusid = 0   '+CHAR(13)+				
				'AND Liveindicator = '+convert(varchar(10),@Liveindicator)+'  '+CHAR(13)+	
		CASE 
			WHEN @Stake=0 AND @MaxStake>0 THEN 'AND Stake < '+convert(varchar(10),@MaxStake) 
			WHEN @Stake>0 AND @MaxStake=0 THEN 'AND Stake > '+convert(varchar(10),@Stake) 
			WHEN @Stake>0 AND @MaxStake>0 THEN 'AND Stake between '+convert(varchar(10),@Stake) +' and ' +convert(varchar(10),@MaxStake) 
		ELSE ' ' END + CHAR(13) +
				
				
		CASE WHEN @Currency <> 'ALL' THEN 'AND currency in ('+@Currency+') 'ELSE ' ' END + CHAR(13)+
		--
		CASE WHEN @LicenseeType <> 'ALL' THEN 'AND [Description] = '''+@LicenseeType+'''' ELSE ' '	END + CHAR(13)+
		CASE WHEN @SpecialLevel <> 'ALL' THEN 'AND SpecialLevel IN ('+@SpecialLevel+')'	ELSE ' ' END+ CHAR(13)+
		CASE WHEN @SportID>0 and @Sportid <> 999 THEN'AND ( b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 )' ELSE ' ' END+ CHAR(13)+
		CASE  
			WHEN @bettype = 'HDP' AND @SportID<>999 THEN 'AND  b.bettype IN (1,7)  '  
			WHEN @bettype = 'OU' AND @SportID<>999 THEN ' AND b.bettype IN (3,8)  '   
			WHEN @bettype = 'Others' AND @SportID<>999 THEN ' AND b.bettype NOT IN (1,3,7,8)  '  
		ELSE ' ' END + CHAR(13)+ 
		
		CASE 
			WHEN @SportID=999 THEN 'AND b.bettype IN (9,29) ' 
			ELSE ' ' 
		END  + CHAR(13)+ 			
		
		'ORDER BY transid desc'
	
IF (@debug = 1) 
	PRINT @sql  
ELSE 
	EXEC(@sql)  	
GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_BetlistSel_ByLeague_new] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_BetlistSel_ByLeague_new] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_BetlistSel_ByLeaguenew] TO [vnteam] AS [dbo]	
	