USE [bodb02]
GO


ALTER PROCEDURE [dbo].[Task_DepWinlost_SyncData]	
AS
/*   
 Task : arrange bettransDEP data
 DB: DB054.bodb02  
 Revisions:   
  - 20121001@viet: create SP
  - 20140520@Johnson: remove table bettransParlay  
  - 20141125@Don: Adjustment to serve to change KeenOcean's currency RMB to HK$
*/  
BEGIN
	SET NOCOUNT ON
	declare @_tstamp binary(8)
	DECLARE @yesterday datetime
	
	SET @yesterday = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP)-1, 0)
	
	SELECT @_tstamp = cast(cast(isnull(vvalue,0) as bigint) as binary(8))
	FROM dbo.systemsettings2 with(rowlock) 
	WHERE vname = 'Task_DepWinlost'	
	
	declare @today smalldatetime
	SET @today = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP), 0)			
	
	IF @_tstamp = 0x0000000000000000 -- 0: renew all data
	BEGIN
		SELECT @_tstamp = max(tstamp) FROM bodb02.dbo.bettrans with(nolock) 
		
		UPDATE dbo.systemsettings2 with(rowlock, updlock)
		SET --vvalue = vvalue2
			--,vvalue2 = cast(cast(@_tstamp as bigint) as varchar(200))
			vvalue = cast(cast(@_tstamp as bigint) as varchar(200))
		WHERE vname = 'Task_DepWinlost'		
		
		RETURN
	END					
			
	DECLARE @tempTransID as TABLE(transid bigint, tstamp binary(8))
	INSERT INTO @tempTransID (transid, tstamp)
	select b.transid, b.tstamp--, b.matchid, b.srecommend
	from dbo.bettrans b with(READPAST)
	where tstamp > @_tstamp
	
	IF @@ROWCOUNT = 0 RETURN -- no new row
	
	SELECT @_tstamp = max(tstamp) FROM @tempTransID 		
	UPDATE dbo.systemsettings2 with(rowlock, updlock)
	SET vvalue = cast(cast(@_tstamp as bigint) as varchar(200))
	WHERE vname = 'Task_DepWinlost'			

	CREATE TABLE #DepositCustSuper(CustID INT, Currency INT)
	DECLARE @Sql VARCHAR(500)
	SET @Sql = 
		'INSERT INTO #DepositCustSuper(CustID, Currency)
		SELECT CustID, Currency
		FROM OPENQUERY(DBLIC,''SELECT CustID, Currency FROM bodb_licensee.dbo.f_SelDepCustSuper('''''''')'')'
	EXEC(@Sql)
					
	CREATE TABLE #TempData(transid bigint, matchid int, srecommend int, isBA bit, currency int)
	INSERT INTO #TempData(transid, matchid, srecommend, isBA, currency)
		SELECT transid, matchid, srecommend, 0, b.currency
		FROM dbo.bettrans b WITH(READPAST)
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = b.srecommend AND s.Currency = b.currency
		WHERE transid IN (SELECT transid FROM @tempTransID)
			AND winlostdate >= @yesterday
			
	UPDATE D
		SET isBA = 1
	FROM #TempData D		
		INNER JOIN DB052.bodb_licensee.dbo.LicenseeBATransaction_active s WITH(NOLOCK)
			ON s.transid = d.transid
	
	DELETE dbo.bettransDEP 
	FROM #TempData s
	WHERE bettransDEP.transid = s.transid
	
	DECLARE @tempCustPending TABLE (custid int, winlostdate smalldatetime)
	
	INSERT INTO dbo.bettransDEP (
		transid, custid, transdate, stake, status, winlost, awinlost, mwinlost, playercomm, comm, 
		acomm, livehomescore, liveawayscore, liveindicator, refno, winlostdate, actualrate, matchid, 
		recommend, mrecommend, ruben, bettype, actual_stake, currency, scomm, swinlost, srecommend, 
		Username, statusID, isBA
	)
	OUTPUT inserted.custid, inserted.winlostdate INTO @tempCustPending(custid, winlostdate)
	SELECT t.transid, custid, transdate, stake, status, winlost, awinlost, mwinlost, playercomm, comm, 
		acomm, livehomescore, liveawayscore, liveindicator, refno, winlostdate, actualrate, b.matchid, 
		recommend, mrecommend, ruben, bettype, actual_stake, b.currency, scomm, swinlost, b.srecommend, 
		Username, statusID, isBA
	FROM dbo.bettrans b with(READPAST)	
		INNER JOIN #TempData t on b.transid = t.transid	

	MERGE dbo.Dep_CustomerPendingCalculate WITH(ROWLOCK, UPDLOCK) as d
		USING (	SELECT distinct custid, case when winlostdate > @Today then @Today else winlostdate end as winlostdate
				FROM @tempCustPending
			)s on d.custid = s.custid and d.winlostdate = s.winlostdate				
		WHEN NOT MATCHED THEN 
		INSERT (custid, winlostdate)
		VALUES (s.custid, s.winlostdate)
	;--end MERGE	
	DROP TABLE #TempData
	SET NOCOUNT OFF
END
GO