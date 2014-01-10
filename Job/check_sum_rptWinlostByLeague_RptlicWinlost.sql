DECLARE @fromdate DATETIME, @todate DATETIME,@recommend INT
SELECT @fromdate='2013-12-21',@todate='2013-12-23',@recommend=7664227

begin
SELECT SUM(turnover),SUM(BetCount) betcount, SUM(winlost)
 FROM bodb_licensee.dbo.rptLicWinloss2 WHERE winlostdate BETWEEN @fromdate AND @todate
AND  recommend=@recommend 
AND statusid IN (111,112,113) 
AND roleid=1

SELECT SUM(stake),SUM(BetCount) betcount, SUM(winlost)
  FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague WHERE winlostdate BETWEEN  @fromdate AND @todate
AND  recommend=@recommend AND statusid IN (111,112,113)
END  