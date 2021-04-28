/*<info serverAlias="DBACC-bodb02" executers="Dot_Admin,Dot_Member" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Dep_Rpt_BetList_SelWinloss_Agent]
    @fromdate smalldatetime,
    @todate smalldatetime,
    @agentid VARCHAR(3500),
    @sporttype int
AS
/*
DB: DBACC.bodb02
Revisions: 

--20131004@Jeff(bodb06): Add new condition (Virtual Horse Racing)
--20140117@Chun(bodb06): Add new condition (Horse Odds Fixed)
--20140212@chun(db06):Remove sitename from username2
--20170825@Benson(DB06.bodb02): add 'Mix Parlay' bettype(2799) for Betradar virtual sports
--20190115@Benson(DB06.bodb02): Add new condition (Happy 5)
--20200916@Benson(DB06.bodb02): Add new bettype=91 for Number game

*/
BEGIN
	SET NOCOUNT ON;

	IF (@sporttype = 101) -- MixParlay
		BEGIN		
			select
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and 
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype = 9
				and b.recommend in (SELECT val FROM strSplit(@agentid,',')) 		
		END
	ELSE IF(@sporttype = 102) -- OutRight
		BEGIN
			SELECT
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				match.matchcode,
				a.teamname as home,
				'' as away,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			FROM bettrans as b with (nolock) 
				inner join customer as c  with (nolock) on b.custid=c.custid 
				inner join bettype as t with (nolock) on t.typeid=b.bettype 
				inner join outright as match with (nolock) on b.matchid=match.orid
				inner join team a with (nolock) on a.teamid=match.teamid 
			WHERE
				b.winlostdate between @fromdate and @todate
				and b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.ruben=1 
				and b.bettype = 10
				and b.recommend in (SELECT val FROM strSplit(@agentid,',')) 
			ORDER BY
				b.status, b.transid
		END	

	ELSE IF(@sporttype = 151) -- Horse
		BEGIN
		
			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and 
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype in (31,32,33,41,42,43)
				and b.recommend in (SELECT val FROM strSplit(@agentid,','))				
		END	

	ELSE IF(@sporttype = 154) -- Horse Odds Fixed
		BEGIN
		
			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
				inner join match m with (NOLOCK) on b.matchid=m.matchid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and 
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype = 20
				and b.recommend in (SELECT val FROM strSplit(@agentid,','))
				and m.sporttype = @sporttype
		END	

	ELSE IF(@sporttype = 161) -- /Number Game
		BEGIN
			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype in (81,82,83,84,85,86,87,88,89,90,91)
				and b.recommend in (SELECT val FROM strSplit(@agentid,','))
		END	
	ELSE IF(@sporttype = 162) -- Live Casino
		BEGIN
			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype between  1101 and 1199
				and b.recommend in (SELECT val FROM strSplit(@agentid,','))		
		END	
	ELSE IF(@sporttype = 164) -- Happy 5
		BEGIN
			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype between 8101 and 8105
				and b.recommend in (SELECT val FROM strSplit(@agentid,','))
		END		
	ELSE IF(@sporttype = 181) -- Virtual Horse Racing
		BEGIN

			SELECT
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and 
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype in (1231,1232,1233,1237,1238)
				and b.recommend in (SELECT val FROM strSplit(@agentid,','))		
		END	
	ELSE IF(@sporttype = 199) -- Mix Parlay(Virtual Sports)
		BEGIN
			select
				c.custid,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2,0)+1, 50) as username2,
				t.typenamee,
				convert(nvarchar,b.transid) AS refno,
				b.bettype,
				b.transid,
				b.odds,
				b.status,
				b.stake*b.actualrate as stake,
				(winlost-actual_stake)*b.actualrate as Winloss,
				b.transdate,
				b.betteam
			from bettrans as b WITH (NOLOCK) 
				inner join customer as c with (NOLOCK) on c.custid=b.custid
				inner join bettype as t with (NOLOCK) on b.bettype=t.typeid
			where
				b.winlostdate between @fromdate and @todate and
				b.ruben=1 and 
				b.statusID not in (101, 102, 103) --101:reject, 102:void, 103:refund 
				and b.bettype = 2799
				and b.recommend in (SELECT val FROM strSplit(@agentid,',')) 	
		END	
		
END
GO