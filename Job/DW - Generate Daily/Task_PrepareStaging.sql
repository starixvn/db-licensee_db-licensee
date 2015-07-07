USE [bodb_Licensee]
GO
ALTER PROCEDURE [dbo].[Task_PrepareStaging]  
    @datefrom smalldatetime=null
    ,@dateto smalldatetime=null
WITH RECOMPILE
AS  
/*
Created: 
Task: 
DB: DB052.bodb_Licensee

Revisions:
    -20120423@Jim: Add more information for BARM agent 
    -20120613@Don: Fixed bug 'custid=0'
    -20150127@Don: Expand bet type ranges for Sportbook when processing BA
	-20150324@Jim: exclude waiting ticket
	-20150623@Patrick: Support BetTrade

Param's Explanation:

*/
BEGIN
	
	DECLARE @today datetime, @thedaybefore datetime
	SELECT @today=@dateto, @thedaybefore=@datefrom
	
    IF (NOT (@today IS NULL OR @thedaybefore IS NULL))
        SELECT @today=CONVERT(varchar(10),DATEADD(day,1,@today),120), @thedaybefore=CONVERT(varchar(10),@thedaybefore,120)
    ELSE
        SELECT @today=CONVERT(varchar(10),current_timestamp,120), @thedaybefore=DATEADD(day,-3,@today)
    
	---------PROCESS OUTRIGHT DATA--------------------------------------------------------------------------------------------  
	TRUNCATE TABLE dbo.outright  
	
    INSERT INTO dbo.outright(matchid, leagueid)
	    SELECT orid AS matchid, leagueid
        FROM bodb02.dbo.outright (NOLOCK)
        WHERE eventdate>=@thedaybefore AND eventdate<@today
        UNION 
        SELECT orid AS matchid, leagueid
        FROM bodb02.dbo.outright14 (NOLOCK)
        WHERE eventdate>=@thedaybefore AND eventdate<@today

	---------PROCESS MATCH DATA--------------------------------------------------------------------------------------------  
	TRUNCATE TABLE dbo.match  
	
    INSERT INTO dbo.match(matchid, leagueid)
	    SELECT matchid, leagueid
        FROM bodb02.dbo.match (NOLOCK)
        WHERE eventdate>=@thedaybefore AND eventdate<@today
        UNION
        SELECT matchid, leagueid
        FROM bodb02.dbo.match14 (NOLOCK)
        WHERE eventdate>=@thedaybefore AND eventdate<@today
	  
	---------PROCESS BETTRANS DATA--------------------------------------------------------------------------------------------  
	TRUNCATE TABLE dbo.[bettrans]  
	
	DECLARE @Recommend_List TABLE (t_recommend int PRIMARY KEY)

    /*create table #Recommend_List(t_recommend int)
    --create clustered index cix_t_recommend on #Recommend_List(t_recommend)
    create unique nonclustered index ix_t_recommend on #Recommend_List(t_recommend)*/
    
    CREATE TABLE #Customer (t_custid int PRIMARY KEY)
	CREATE TABLE #BetTradeCust (custid int PRIMARY KEY)

	INSERT INTO #BetTradeCust(CustId)
	SELECT CustId FROM bodb02.dbo.f_GetBetTradeCustList('ALL')
    
    DECLARE @count int,@movebetdate smalldatetime,@tmpDate smalldatetime
	SELECT @count=DATEDIFF(DAY,@thedaybefore,@today) - 1
	SELECT @movebetdate=MAX(winlostdate) FROM bodb02.dbo.bettrans14 (NOLOCK)

	WHILE (@count>=0)
	BEGIN
		SELECT @tmpDate=DATEADD(DAY,@count,@thedaybefore)
		
		IF (@tmpDate > @movebetdate)
		BEGIN
			--Copy LIVE data (bettrans) 
			DELETE @Recommend_List
		
		    INSERT INTO @Recommend_List
                SELECT DISTINCT recommend FROM bodb02.dbo.bettrans (NOLOCK) WHERE winlostdate=@tmpDate AND bettype<19000
                
            /*INSERT INTO #Recommend_List
                SELECT DISTINCT recommend FROM bettrans (NOLOCK) WHERE winlostdate=@tmpDate AND bettype<19000 */
            
			INSERT INTO dbo.bettrans
			    ([transid]
                ,winlostdate
                ,liveindicator
                ,bettype
                ,[custid]
                ,[stake]
                ,actual_stake
                ,[winlost],[awinlost],[mwinlost],swinlost
                ,acomm,scomm,playercomm,comm
                ,matchid
                ,[status]
                ,[srecommend]
                ,currency
                ,recommend,mrecommend
                ,transdate
                ,statusid
                ,virtualrate
                ,discount
                ,tpositiontaking
                ,customercategory)
			SELECT 
			    b.transid,
	            b.winlostdate,
	            b.liveindicator,
	            b.bettype,
	            b.custid,
	            ABS(b.stake) stake,
	            b.actual_stake,
	            b.winlost,b.awinlost,b.mwinlost,b.swinlost,
	            b.acomm, b.scomm, b.playercomm, b.comm,
	            b.matchid,
	            CASE WHEN (b.bettype IN (1, 3, 7, 8, 17, 18, 124, 125) AND ABS(b.modds) = 0.25 AND [status] IN('WON', 'LOSE')) OR (b.bettype IN (33,43) AND [status] <> 'refund' AND b.liveawayscore=0) THEN 'HALF ' ELSE '' END + b.status AS [status],
                b.srecommend, 
                b.currency, 
                b.recommend,b.mrecommend,
                b.transdate,
                --CASE WHEN b.status='HALF WON' THEN 114 WHEN b.status='HALF LOSE' THEN 115 ELSE b.statusid END statusid, -- Error due to [status] column above
                b.statusid,
                b.virtualrate,
                b.discount,
                b.tpositiontaking,
                CASE WHEN b.recommend=52466 THEN 27 --8RM
					 WHEN b.recommend=5707545  THEN 28 -- BARM
					ELSE -1 END customercategory 
			FROM bodb02.dbo.bettrans b (NOLOCK)
			    INNER JOIN @Recommend_List r ON b.recommend=r.t_recommend
			WHERE b.bettype<19000
			    --AND b.statusid NOT IN (0,101,102,121)  -- 'void', 'reject', 'running','done'
	            AND b.winlostdate=@tmpDate
	            AND b.custid>0
	            
            DELETE dbo.bettrans WHERE winlostdate=@tmpDate AND statusid IN (0,1,101,102,121)
        END
		ELSE
        BEGIN
			--Copy archived data (bettrans14)
			TRUNCATE TABLE #Customer
			
			INSERT INTO #Customer
	            SELECT DISTINCT custid
	            FROM bodb02.dbo.bettrans14 (NOLOCK)
	            WHERE winlostdate=@tmpDate AND custid>0
	            
			INSERT INTO dbo.bettrans
			    ([transid]
                ,winlostdate
                ,liveindicator
                ,bettype
                ,[custid]
                ,[stake]
                ,actual_stake
                ,[winlost],[awinlost],[mwinlost],swinlost
                ,acomm,scomm,playercomm,comm
                ,matchid
                ,[status]
                ,[srecommend]
                ,currency
                ,recommend,mrecommend
                ,transdate
                ,statusid
                ,virtualrate
                ,discount
                ,tpositiontaking
                ,customercategory)
			SELECT 
			    b.transid,
	            b.winlostdate,
	            b.liveindicator,
	            b.bettype,
	            b.custid,
	            ABS(b.stake) stake,
	            b.actual_stake,
	            b.winlost,b.awinlost,b.mwinlost,b.swinlost,
	            b.acomm, b.scomm, b.playercomm, b.comm,
	            b.matchid,
	            CASE WHEN (b.bettype IN (1, 3, 7, 8, 17, 18, 124, 125) AND ABS(b.modds) = 0.25 AND [status] IN('WON', 'LOSE')) OR (b.bettype IN (33,43) AND [status] <> 'refund' AND b.liveawayscore=0) THEN 'HALF ' ELSE '' END + b.status AS [status],
                b.srecommend, 
                b.currency, 
                b.recommend,b.mrecommend,
                b.transdate,
                --CASE WHEN b.status='HALF WON' THEN 114 WHEN b.status='HALF LOSE' THEN 115 ELSE b.statusid END statusid,
                b.statusid,
                b.virtualrate,
                b.discount,
                b.tpositiontaking,
                CASE WHEN b.recommend=52466 THEN 27 --8RM
					 WHEN b.recommend=5707545 THEN 28 	--BARM
					ELSE -1 END customercategory 
			FROM bodb02.dbo.bettrans14 b (NOLOCK)
			    INNER JOIN #Customer c (NOLOCK) ON b.winlostdate=@tmpDate AND b.custid=c.t_custid
			WHERE b.statusid NOT IN (0,101,102,121)  -- 'void', 'reject', 'running','done'
        END

		SELECT @count = @count - 1
	END
	
	--DROP TABLE #Recommend_List
	DROP TABLE #Customer
	
	
	UPDATE dbo.bettrans
	SET statusid=CASE WHEN [status]='HALF WON' THEN 114 WHEN [status]='HALF LOSE' THEN 115 END
	WHERE [status] IN ('HALF WON','HALF LOSE')
	
	--///// PROCESS UPDATE BA STATUS FOR TICKETS ///////////////////
    DECLARE @BATransids AS TABLE (transID bigint)

    SELECT @today = current_timestamp

    INSERT @BATransids
        SELECT transid
        FROM dbo.bettrans b (NOLOCK)
	        INNER JOIN dbo.LicenseeBAHistory h (NOLOCK) 
	            ON b.custid=h.custid AND (transdate BETWEEN OnDate AND ISNULL(OffDate,@today))
        WHERE (Bettype<31 OR (Bettype>=121 AND Bettype<1000) OR (Bettype>=1301 AND Bettype<1400))
	        AND tpositiontaking=0

    UPDATE dbo.bettrans 
    SET IsBA=1
    WHERE transid IN (SELECT transid FROM @BATransids)

	--turn on bettrade members
	UPDATE dbo.bettrans 
    SET customercategory = 2001 --bettrade
    WHERE custid IN (SELECT CustId FROM #BetTradeCust)
		OR Bettype = 901

	DROP TABLE #BetTradeCust
	  
END
GO
GRANT EXECUTE ON [dbo].[Task_PrepareStaging] TO [vnteam] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Task_PrepareStaging] TO [vnteam] AS [dbo]