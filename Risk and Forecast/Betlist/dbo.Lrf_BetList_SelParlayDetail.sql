USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelParlayDetail]    Script Date: 04/24/2015 08:52:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelParlayDetail]
	@TransID	bigint,
	@Langkey	VARCHAR(10) = 'en-US'
 AS
/*
Created: Henry@20101210
Task : get parlay tickets
DB: DB052.bodb02
Original: [Age_BetList_SelParlayDetail]

Revisions:    
	- 20110930@Henry: Add column statusID
	- 20111229@Henry: change the way to get odds/oddstype/betteam to web dev
	- 20141106@Florent: fix show SS bettype, get betcheck
	- 20141212@Florent: fix when betcheck = '' will return NULL
	- 20150424@Jim: support Betradar (add column betcheck in result)
*/
SET NOCOUNT ON

DECLARE @tmpParlay TABLE (
	transid BIGINT
	,betID TINYINT
	,betcheck VARCHAR(100)
	,sporttype INT
	,leagueid INT
	,bettype INT
	,homeid INT
	,awayid INT
	,hdp1 FLOAT
	,hdp2 FLOAT
	,odds SMALLMONEY
	,betteam NVARCHAR(50)
	,livehomescore SMALLINT
	,liveawayscore SMALLINT
	,liveindicator BIT
	,betstatus NVARCHAR(50)
	,isNeutral BIT
	,statusID INT
	)
DECLARE @refno BIGINT
	,@custID INT

SELECT @refno = refno
	,@custID = custid
FROM bettrans WITH (NOLOCK)
WHERE TransID = @TransID

IF @refno IS NULL
BEGIN
	SELECT @refno = refno
		,@custID = custid
	FROM bettrans14 WITH (NOLOCK)
	WHERE TransID = @TransID

	IF @refno IS NULL
	BEGIN
		SELECT @refno = refno
			,@custID = custid
		FROM DB06.bodb_archive.dbo.bettrans_BK WITH (NOLOCK)
		WHERE TransID = @TransID
	END
END

IF EXISTS (
		SELECT 1
		FROM bettransm WITH (NOLOCK)
		WHERE refno = @refno
			AND custid = @custid
		)
BEGIN
	INSERT INTO @tmpParlay (
		transid
		,betID
		,betcheck
		,sporttype
		,leagueid
		,bettype
		,homeid
		,awayid
		,hdp1
		,hdp2
		,odds
		,betteam
		,livehomescore
		,liveawayscore
		,liveindicator
		,betstatus
		,isNeutral
		,statusID
		)
	SELECT b.transid
		,NULL 
	    ,b.betcheck
		,m.Sporttype
		,m.LeagueID
		,b.Bettype
		,m.homeID
		,m.awayID
		,convert(FLOAT, b.hdp1) AS Hdp1
		,convert(FLOAT, b.hdp2) AS Hdp2
		,b.odds
		,b.betteam
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,m.betstatus
		,m.isNeutral
		,b.statusID
	FROM (
		SELECT transid
			,CASE WHEN betcheck = '' THEN NULL ELSE betcheck END AS betcheck
			,matchid
			,Bettype
			,hdp1
			,hdp2
			,odds
			,betteam
			,livehomescore
			,liveawayscore
			,liveindicator
			,statusID
		FROM BettransM WITH (NOLOCK)
		WHERE refno = @refno
			AND custID = @custID
		) AS b
	INNER JOIN match AS m WITH (NOLOCK) ON b.matchid = m.matchid
END

IF EXISTS (
		SELECT 1
		FROM bettransm14 WITH (NOLOCK)
		WHERE refno = @refno
			AND custid = @custid
		)
BEGIN
	INSERT INTO @tmpParlay (
		transid
		,betID
		,betcheck
		,sporttype
		,leagueid
		,bettype
		,homeid
		,awayid
		,hdp1
		,hdp2
		,odds
		,betteam
		,livehomescore
		,liveawayscore
		,liveindicator
		,betstatus
		,isNeutral
		,statusID
		)
	SELECT b.transid
		,NULL
		,b.betcheck
		,m.Sporttype
		,m.LeagueID
		,b.Bettype
		,m.homeID
		,m.awayID
		,convert(FLOAT, b.hdp1) AS Hdp1
		,convert(FLOAT, b.hdp2) AS Hdp2
		,b.odds
		,b.betteam
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,m.betstatus
		,m.isNeutral
		,b.statusID
	FROM (
		SELECT transid
			 ,CASE WHEN betcheck = '' THEN NULL ELSE betcheck END AS betcheck
			,matchid
			,Bettype
			,hdp1
			,hdp2
			,odds
			,betteam
			,livehomescore
			,liveawayscore
			,liveindicator
			,statusID
		FROM BettransM14 WITH (NOLOCK)
		WHERE refno = @refno
			AND custID = @custID
		) AS b
	INNER JOIN match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
END

IF EXISTS (
		SELECT 1
		FROM DB06.bodb_archive.dbo.BettransM WITH (NOLOCK)
		WHERE refno = @refno
		)
BEGIN
	INSERT INTO @tmpParlay (
		transid
		,betID
		,betcheck
		,sporttype
		,leagueid
		,bettype
		,homeid
		,awayid
		,hdp1
		,hdp2
		,odds
		,betteam
		,livehomescore
		,liveawayscore
		,liveindicator
		,betstatus
		,isNeutral
		,statusID
		)
	SELECT b.transid
		,NULL
		,b.betcheck
		,m.Sporttype
		,m.LeagueID
		,b.Bettype
		,m.homeID
		,m.awayID
		,convert(FLOAT, b.hdp1) AS Hdp1
		,convert(FLOAT, b.hdp2) AS Hdp2
		,b.odds
		,b.betteam
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,m.betstatus
		,m.isNeutral
		,b.statusID
	FROM (
		SELECT transid
			 ,CASE WHEN betcheck = '' THEN NULL ELSE betcheck END AS betcheck
			,matchid
			,Bettype
			,hdp1
			,hdp2
			,odds
			,betteam
			,livehomescore
			,liveawayscore
			,liveindicator
			,statusID
		FROM DB06.bodb_archive.dbo.BettransM WITH (NOLOCK)
		WHERE refno = @refno
			AND custID = @custID
		) AS b
	INNER JOIN DB06.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
END

SELECT *
FROM @tmpParlay
ORDER BY transID DESC 

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelParlayDetail] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelParlayDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelParlayDetail] TO [vnteam]