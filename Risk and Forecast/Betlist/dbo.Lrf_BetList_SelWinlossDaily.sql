set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

/*
exec Lrf_BetList_SelWinlossDaily
@date='2012-09-04 00:00:00:000',
@LicenseeID=1,
@MoveBetsDay='2012-09-03 00:00:00:000',
@BalanceUpDay='2012-09-01 00:00:00:000'
*/

ALTER  PROCEDURE [dbo].[Lrf_BetList_SelWinlossDaily]
	@date SMALLDATETIME,
	@LicenseeID INT,
	@UserID		INT,
	@CurrencyID INT=0,
	@Product  VARCHAR(10),
	@Status   VARCHAR(10),	
	@Langkey VARCHAR(10) = 'en-US',
	@MoveBetsDay SMALLDATETIME,
	@BalanceUpDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@debug	   BIT=1,	
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY = 0 OUTPUT,
	@SumLicenseeWL MONEY = 0 OUTPUT,
	@SumComm MONEY = 0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY = 0 OUTPUT,
	@SumLicenseeWLUSD MONEY = 0 OUTPUT,
	@SumCommUSD MONEY = 0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY = 0 OUTPUT,
	@SumLicenseeWLEUR MONEY = 0 OUTPUT,
	@SumCommEUR MONEY = 0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT
AS

/*
Created: 20111904@Henry
Task : Betlist
DB: DB052.bodb02
Original:
Revisions:
	- 20110523@Henry: Support Number Game
	- 20110616@Henry: Suport filter BA tickets  
	- 20110712@Henry: Output Licensee WL + remove BA filter
	- 20110729@Henry: offer 3 new bettypes for Number Game
	- 20110927@Henry: return output params instead of secondary table
	- 20111208@Jim: change condition bettype <31 
	- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120723@Jim: add playercomm value 
	- 20120817@Jim: add live casino
	- 20120912@Jim: add virtual sport
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20121016@Henry: enhance SP
	- 20130305@Jim: change input param @winlostdate by @date
	- 20130320@Jim: fix bug wrong Total Rows's value 
	- 20130328@Scott: Support RNG Casino and Bingo
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20130619@Jim: fix bug missing RNG Casino data 
	- 20130716@Jim: update matchid for RNG Casino and Bingo
	- 20131007@Jim: Enhance the usability of Daily Bet List report and offer Virtual Horse Racing & Virtual Tennis
Param's Explanation: 
	
*/
DECLARE @sql VARCHAR(MAX)
DECLARE @wldate SMALLDATETIME
SELECT @sql='SET NOCOUNT ON '+char(13)
SELECT @sql=@sql+'----DECLARE VARIABLE---- '+char(13)
SELECT @sql=@sql+'CREATE TABLE #Data(RowNum INT,
									Sporttype INT,
									Username nvarchar(50),
									NickName NVARCHAR(50),
									Bettype INT,
									LeagueID INT,
									Transid BIGINT,
									Matchcode VARCHAR(50),
									HomeID INT,
									AwayID INT,
									hdp1 SMALLMONEY,
									hdp2 SMALLMONEY,
									odds SMALLMONEY,
									status nvarchar(50),
									stake MONEY,
									Winlost MONEY,
									LicenseeWL   MONEY,
									comm MONEY,
									PlayerComm MONEY,
									transdate DATETIME,
									Winlostdate DATETIME,
									betteam VARCHAR (50),
									liveindicator INT,
									livehomescore SMALLINT,
									liveawayscore SMALLINT,
									MatchID INT,
									Betstatus nvarchar(50),
									IsNeutral BIT,
									oddstype INT,
									betid BIGINT,
									currency SMALLINT,
									RefNO			BIGINT,	
									CustID	INT,
									showtime NVARCHAR(50)
									)'+char(13)
									
	
SELECT @sql=@sql+'CREATE TABLE #DataSum (currency INT,
										totalrows INT,
										SumWinlost 	 MONEY,
										SumLicenseeWL MONEY,
										SumComm MONEY,
										SumPlayerComm MONEY
										)'+char(13)
/*										
SELECT @sql=@sql+'CREATE TABLE #result (RowNum INT,
										sporttype INT,
										username nvarchar(100),
										nickname nvarchar(100),
										bettype INT,
										leagueID INT,
										transid  INT,
										matchcode INT,
										homeID	  INT,
										awayID    INT,
										hdp1 	  FLOAT,
										hdp2 	  FLOAT,
										odds	  smallmoney,
										status	  nvarchar(20),
										stake	  money,
										winlost   money,
										LicenseeWL money,
										comm	   money,
										transdate datetime,
										winlostdate datetime,
										betteam   nvarchar(20),
										liveindicator  bit,
										livehomescore smallint,
										liveawayscore smallint,
										matchid  	  int,
										betstatus	nvarchar(100),
										IsNeutral 	bit,
										OddsType  tinyint,
										betid 	bigint,
										currency tinyint,
										refno  bigint,
										custid int,
										ShowTime nvarchar(100)		
										)'+char(13) */
SELECT @sql=@sql+'										
				DECLARE @BettransDetail TABLE(  
						refno BIGINT,  
						odds SMALLMONEY,  
						stake MONEY,
						status NVARCHAR(10),  
						apositiontaking SMALLMONEY,  
						bettype SMALLINT,
						Betteam nvarchar (10),
						stakeEUR MONEY,
						stakeUSD MONEY
					 ) 	
	'+char(13)	
SELECT @sql=@sql+'DECLARE @TempAg AS TABLE (custid INT)'+char(13)+
				'DECLARE @TmpCondBettype AS TABLE (bettype INT primary key)'+char(13)
				
SELECT @sql=@sql+'INSERT INTO @TmpCondBettype
				  SELECT typeid
				  FROM bettype WITH (NOLOCK)
				  '+char(13)+
					CASE @Product
						WHEN 'SB' THEN 'WHERE typeid < 31 OR   
										typeid BETWEEN 121 AND 999 OR   
										typeid BETWEEN 1301 AND 1334'
						WHEN 'BA' THEN 'WHERE typeid < 31 OR 
										typeid BETWEEN 121 AND 999 OR   
										typeid BETWEEN 1301 AND 1334'
						WHEN 'RB' THEN 'WHERE typeid BETWEEN 31 AND 33'				
						WHEN 'NG' THEN 'WHERE typeid BETWEEN 81 AND 120'
						WHEN 'LC' THEN 'WHERE typeid BETWEEN 1101 AND 1199'
						WHEN 'VS' THEN 'WHERE typeid BETWEEN 1201 AND 1299'
						WHEN 'CS' THEN 'WHERE typeid =71'
						WHEN 'BG' THEN 'WHERE typeid = 73'
						ELSE ''
						END+ char(13)
SELECT @sql=@sql+'SELECT  currencyID,LicenseeID into #currency
					FROM  dbo.Lrf_f_GetCurrencybyUser('+CONVERT(VARCHAR(10),@LicenseeID)+','+CONVERT(VARCHAR(10),@userID)+',1)
					WHERE ('+CONVERT(VARCHAR(10),@CurrencyID)+'=0  OR ('+CONVERT(VARCHAR(10),@CurrencyID)+'<>0 AND CurrencyID='+CONVERT(VARCHAR(10),@CurrencyID)+'))'+char(13)						
SELECT @sql=@sql+'INSERT INTO @TempAg (custid)
				    SELECT  CustID  
				    FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
					INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
		'+char(13)			
SELECT @wldate = @date
DECLARE @RowStart INT, @RowEnd INT  
DECLARE @checktime BIT
DECLARE @checkVHR  BIT
IF @wldate > @MoveBetsDay
	SET @checktime=1
ELSE 
	IF @wldate BETWEEN @MoveBetsDay AND @BalanceUpDay
		SET @checktime=0
IF @Product='VS'
	SET @checkVHR=1
ELSE 
	SET @checkVHR=0
	
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

IF @checkVHR=1
BEGIN
	SELECT @sql=@sql+'SELECT o.OriD
					,r.Sporttype
					,r.LeagueID
					,CONVERT (VARCHAR(50),o.RacerNum) matchcode
					,o.RacerID homeID 
					,r.BetStatus 
					,r.EventTime   ShowTime
					INTO #vhr'+char(13)+
					CASE @checktime
					WHEN 1 THEN ' FROM VSOutright o with (nolock) '
						ELSE  'FROM VSOutright14 o with (nolock)' END +char(13)+
					'INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID'+char(13)+
					'WHERE  o.EventDate ='''+CONVERT(varchar(10),@wldate,120)+char(13)	
END
SELECT @sql=@sql+'INSERT INTO #DataSum'+char(13)+
				'SELECT 
				currency,
				COUNT(b.transid),
				SUM(ISNULL(b.winlost-b.actual_stake,0)),
				SUM(ISNULL('+CASE WHEN @Product<>'BA' THEN '- (b.winlost-b.actual_stake)' ELSE '0' END+',0)),
				SUM(ISNULL(b.comm,0)),
				SUM(b.playercomm )  AS  SumPlayerComm
			FROM bettrans b WITH (nolock)'+char(13)+
			'LEFT JOIN match m WITH (nolock) ON b.matchid=m.matchid'+char(13)+
			CASE @Product
				WHEN 'ALL' THEN ''
				WHEN 'BA'  THEN 'INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
								 LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid'
				ELSE 'INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype'
				END + char(13)+
			'WHERE
				b.winlostdate = '''+CONVERT(VARCHAR(20),@wldate,120)+'''
				AND b.matchid > 0
				AND b.bettype NOT IN (9,29,10)
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND b.ruben = 1
				'+char(13)+
			'GROUP BY currency'	+ char(13)
SELECT @sql=@sql+'
				SELECT
					ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
					m.sporttype,
					b.username,
					SUBSTRING(c.username2,  CHARINDEX('+'''$'''+',c.username2)+1, len(c.username2)-CHARINDEX('+'''$'''+',c.username2)) AS nickname,
					b.bettype,
					m.leagueID,			
					b.transid,
					m.matchcode,
					m.homeID,
					m.awayID,
					CONVERT(FLOAT, b.hdp1) AS hdp1, 
					CONVERT(FLOAT, b.hdp2) AS hdp2, 
					b.odds,
					b.status,
					b.stake,
					(b.winlost-actual_stake) winlost,'+char(13)+
					CASE WHEN @Product<>'BA' THEN '- (b.winlost-b.actual_stake)' ELSE '0' END +char(13)+'AS LicenseeWL ,
					b.comm as comm,
					b.playercomm as PlayerComm,
					b.transdate,
					b.winlostdate,
					b.betteam,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.matchid, 
					m.betstatus,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					b.OddsType,
					b.betid,
					b.currency,
					b.refno,
					b.custid,
					CASE WHEN (b.bettype BETWEEN 1101 AND 1199 OR b.bettype IN (1231, 1232, 1233, 1237, 1238)) THEN  ISNULL(m.showtime,'''') ELSE '''' END AS ShowTime
					INTO #result
				FROM
				'+char(13)+
			CASE @checktime WHEN 1 THEN 'dbo.bettrans b WITH (nolock)
										' ELSE 'dbo.bettrans14 b WITH (nolock)' END+char(13)
				IF (@Product<>'VS' AND @Product<>'BA')
				BEGIN 
					SELECT @sql=@sql+ CASE WHEN @checktime=1 
										 THEN 'INNER JOIN match m WITH (nolock) ON b.matchid=m.matchid 
											  INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
											  INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype' 	
										 ELSE 'INNER JOIN match14 m WITH (nolock) ON b.matchid=m.matchid 
											  INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
											  INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype'
									END
				END 					
			    IF @Product='BA' 
				BEGIN
						SELECT @sql=@sql+CASE WHEN @checktime=1 
							 THEN 'INNER JOIN match m WITH (nolock) ON b.matchid=m.matchid 
								  INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
								  INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
								  INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
								  ' 	
							 ELSE 'INNER JOIN match14 m WITH (nolock) ON b.matchid=m.matchid 
								  INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
								  INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
								  INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
								  '
						END	
				END		
				IF @Product='VS' 
				BEGIN 
						SELECT @sql=@sql+ 
						CASE WHEN (@checktime=1 AND @checkVHR<>1)
							 THEN 'INNER JOIN match m WITH (nolock) ON b.matchid=m.matchid 
								  INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
								  INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
								  ' 	
							 WHEN (@checktime=0 AND @checkVHR<>1)
							 THEN 'INNER JOIN match14 m WITH (nolock) ON b.matchid=m.matchid 
								  INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
								  INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
								  '
							WHEN (@checkVHR=1)
							THEN 'INNER JOIN #vhr m ON b.oddsid=m.Orid
								  INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
								  INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
								  '+char(13)
						END		  
					SELECT @sql=@sql+'DROP TABLE #vhr'		
				END	  
			SELECT @sql=@sql+ 	
			'
			WHERE
				b.winlostdate = '''+CONVERT(VARCHAR(20),@wldate,120)+'''
				AND b.bettype NOT IN (9,29,10)
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND b.status='''+CONVERT(VARCHAR(20),@Status)+'''
			'+char(13)
SELECT @sql=@sql+'INSERT INTO #Data
				  SELECT A.* 
				  FROM #result A
				  WHERE A.RowNum BETWEEN '+CONVERT(VARCHAR(20),@RowStart)+' AND '+CONVERT(VARCHAR(20),@RowEnd)+char(13)
				 
SELECT @sql=@sql+'
				SELECT * INTO #TempExchange 
				FROM Lrf_f_GetExchangeDaily('''+CONVERT(VARCHAR(20),@wldate,120)+''','''+CONVERT(VARCHAR(20),@wldate,120)+''')'+ char(13)+
				'WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)	
				'+char(13)				
SELECT @sql=@sql+'
				SELECT  
				b.* ,
				--USD
				stake*e.USD stakeUSD,
				Winlost*e.USD WinlostUSD,
				LicenseeWL*e.USD LicenseeWLUSD,
				comm*e.USD commUSD,
				playercomm*e.USD as PlayerCommUSD,
				--EUR
				stake*e.EUR stakeEUR,
				Winlost*e.EUR WinlostEUR,
				LicenseeWL*e.EUR LicenseeWLEUR,
				comm*e.EUR commEUR,
				playercomm*e.EUR as PlayerCommEUR
		FROM #Data b
			INNER JOIN #TempExchange e 
		ON  e.exchangeid = b.currency
				'+char(13)
	
IF (@Product='LC' OR @Product='VS')
	BEGIN 
		--- SUM
		SELECT @sql=@sql+'
					SELECT * INTO #TempExchangeSum 
					FROM Lrf_f_GetExchangeDaily('''+CONVERT(VARCHAR(20),@wldate,120)+''','''+CONVERT(VARCHAR(20),@wldate,120)+'''
					WHERE exchangeid IN (SELECT DISTINCT Currency FROM #DataSum)
					'+char(13)
					
		SELECT @sql=@sql+'
						SELECT 
						@TotalRows = SUM(TotalRows),
						@SumWinlost = SUM(SumWinlost),
						@SumLicenseeWL = SUM(SumLicenseeWL),
						@SumComm = SUM(SumComm),
						@SumPlayerComm=SUM(ISNULL(SumPlayerComm,0)),
						--USD
						@SumWinlostUSD = SUM(SumWinlost*e.USD),
						@SumLicenseeWLUSD = SUM(SumLicenseeWL*e.USD),
						@SumCommUSD = SUM(SumComm * e.USD),
						@SumPlayerCommUSD=SUM(ISNULL(SumPlayerComm,0)*e.USD),
						--EUR
						@SumWinlostEUR = SUM(SumWinlost*e.EUR),
						@SumLicenseeWLEUR = SUM(SumLicenseeWL*e.EUR),
						@SumCommEUR = SUM(SumComm * e.EUR),
						@SumPlayerCommEUR=SUM(ISNULL(SumPlayerComm,0)*e.EUR)
					FROM #DataSum b 
					INNER JOIN #TempExchangeSum e 
					ON b.currency = e.exchangeid
						'+char(13)
				
		SELECT @sql=@sql+'INSERT INTO @BettransDetail
						SELECT 
							BG.refno, 
							BG.odds, 
							BG.stake,
							BG.status, 
							BG.apositiontaking, 
							BG.bettype  ,
							BG.Betteam  ,
							BG.stake * e.EUR AS stakeEUR,
							BG.stake * e.USD AS stakeUSD'+char(13)+
					CASE WHEN @Product='LC' AND @checktime=1 THEN
							'
							FROM bettransg BG WITH (NOLOCK)
							'
						WHEN @Product='LC' AND @checktime=0 THEN
							'
							FROM bettransg14 BG WITH (NOLOCK)
							'
						WHEN @Product='VS' AND @checktime=1 AND @checkVHR=1 THEN
							'
							FROM bettransm BG WITH (NOLOCK)
							'
						WHEN @Product='VS' AND @checktime=0 AND @checkVHR=1 THEN
							'
							FROM bettransm BG WITH (NOLOCK)
							'
						ELSE ''
						END +char(13)+
				'INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.CustID
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency'+char(13)+
				CASE WHEN @Product='LC' THEN 'WHERE B.Bettype BETWEEN 1101 AND 1199' 
					 WHEN @Product='VS' THEN 'WHERE B.Bettype=1233'	
					 END+char(13)
		SELECT @sql=@sql+'SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype'	
		SELECT @sql=@sql+'DROP TABLE #TempExchangeSum '+char(13)
	END			
SELECT @sql=@sql+'DROP TABLE #Data
				DROP TABLE #DataSum
				DROP TABLE #result
				DROP TABLE #currency
				DROP TABLE #TempExchange
				'+char(13)		
IF (@debug = 1) 
	PRINT @sql
ELSE
	EXEC @sql
		
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossDaily] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossDaily] TO vnteam
