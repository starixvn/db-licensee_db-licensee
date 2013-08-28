USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Result_Outright]    Script Date: 08/28/2013 06:49:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.Lrf_Result_Outright    Script Date: 4/8/2013 10:42:05 PM ******/

ALTER PROCEDURE [dbo].[Lrf_Result_Outright]
    @FromDate DATETIME,
    @ToDate DATETIME,
    @isShowAll BIT = 1 -- 1: Show All; 0: is NOT show Test
AS 

/*
Created: 20101201@Jacob
Task: Get Result Outright (exclude Horse Racing)
DB: DB05.bodb02
Original: Age_Result_Outright

Revisions:    
    - 20101201@Jacob: Copy source code from Age_Result_Outright
    - 20110308@Henry: exclude Greyhound & Harness racing sports (152,153)  
    - 20110524@Henry: fix Show All/is not show test
    - 20110630@Jamie: Add REFUND Result cho Outright 
*/
SET NOCOUNT ON 

SELECT @isShowAll = CASE @isShowAll WHEN 1 THEN NULL ELSE 0 END

SELECT DISTINCT 
        league.sporttype, outright.leagueid, outright.eventdate, outright.teamid, 
        outright.status
    FROM         
        (SELECT leagueid, eventdate, teamid, status
         FROM dbo.outright AS o1 with (nolock)
         WHERE oddsstatus = 'completed' AND [status] IN ( 'WON','REFUND')
            AND eventdate >= @FromDate AND eventdate <= @ToDate
         UNION ALL
         SELECT leagueid, eventdate, teamid, status
         FROM dbo.outright14 AS o14 with (nolock)
         WHERE oddsstatus = 'completed' AND [status] IN( 'WON','REFUND')
            AND eventdate >= @FromDate AND eventdate <= @ToDate
        ) AS outright 
         INNER JOIN dbo.league with (nolock) on outright.leagueid = league.leagueid
    WHERE league.sporttype not in (151,152,153) 
    AND league.isTest = isnull(@isShowAll, league.isTest)
    ORDER BY outright.leagueid,outright.eventdate, outright.teamid
    



GO
GRANT EXECUTE ON [dbo].[Lrf_Result_Outright] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_Result_Outright] TO [vnteam] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Result_Outright] TO [vnteam] AS [dbo]