ALTER PROCEDURE [dbo].[PIH_BettransIns]  
	@strXML NVARCHAR(MAX)
AS  
/*  Created: Viet  
	Date: 2012-07-16
    TASk : Insert data to bettrans in Kahnawake server
    DB: WW100_DB.bodb_PIH @ kahnawake
   
    Revisions:  
		
	Param's Explanation:  
*/  
  
SET NOCOUNT ON  	
	
DECLARE @intDocHandle INT

--Create an internal representation of the XML document.      
EXEC sp_xml_preparedocument @intDocHandle OUTPUT, @strXML      

INSERT INTO [dbo].[bettransPending]
       ([transid]
       ,[custid]
       ,[transdate]
       ,[oddsid]
       ,[hdp1]
       ,[hdp2]
       ,[odds]
       ,[stake]
       ,[status]
       ,[winlost]
       ,[awinlost]
       ,[mwinlost]
       ,[playercomm]
       ,[comm]
       ,[acomm]
       ,[apositiontaking]
       ,[mpositiontaking]
       ,[tpositiontaking]
       ,[playerdiscount]
       ,[discount]
       ,[adiscount]
       ,[livehomescore]
       ,[liveawayscore]
       ,[liveindicator]
       ,[betteam]
       ,[creator]
       ,[refno]
       ,[winlostdate]
       ,[betfrom]
       ,[betcheck]
       ,[checktime]
       ,[oddsspread]
       ,[actualrate]
       ,[matchid]
       ,[recommend]
       ,[mrecommend]
       ,[ruben]
       ,[betid]
       ,[statuswinlost]
       ,[modds]
       ,[bettype]
       ,[betdaqid]
       ,[actual_stake]
       ,[currency]           
       ,[transdesc]
       ,[sdiscount]
       ,[scomm]
       ,[spositiontaking]
       ,[swinlost]
       ,[srecommend]
       ,[Username]
       ,[virtualrate]
       ,[oddstype]
       ,[statusID]
       ,[currency2])
 SELECT [transid]
       ,[custid]
       ,[transdate]
       ,[oddsid]
       ,[hdp1]
       ,[hdp2]
       ,[odds]
       ,[stake]
       ,[status]
       ,[winlost]
       ,[awinlost]
       ,[mwinlost]
       ,[playercomm]
       ,[comm]
       ,[acomm]
       ,[apositiontaking]
       ,[mpositiontaking]
       ,[tpositiontaking]
       ,[playerdiscount]
       ,[discount]
       ,[adiscount]
       ,[livehomescore]
       ,[liveawayscore]
       ,[liveindicator]
       ,[betteam]
       ,[creator]
       ,[refno]
       ,[winlostdate]
       ,[betfrom]
       ,[betcheck]
       ,[checktime]
       ,[oddsspread]
       ,[actualrate]
       ,[matchid]
       ,[recommend]
       ,[mrecommend]
       ,[ruben]
       ,[betid]
       ,[statuswinlost]
       ,[modds]
       ,[bettype]
       ,[betdaqid]
       ,[actual_stake]
       ,[currency]           
       ,[transdesc]
       ,[sdiscount]
       ,[scomm]
       ,[spositiontaking]
       ,[swinlost]
       ,[srecommend]
       ,[Username]
       ,[virtualrate]
       ,[oddstype]
       ,[statusID]
       ,[currency2]
 FROM OPENXML(@intDocHandle,'/root/bettrans',2)     
 WITH
 (
	transid BIGINT,
	custid INT,
	transdate DATETIME,
	oddsid INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	stake MONEY,
	status NVARCHAR(10),
	winlost money,
	awinlost money,
	mwinlost money,
	playercomm money,
	comm money,
	acomm money,
	apositiontaking smallmoney,
	mpositiontaking smallmoney,
	tpositiontaking smallmoney,
	playerdiscount decimal (9, 8),
	discount decimal(9, 8),
	adiscount decimal(9, 8),
	livehomescore smallint,
	liveawayscore smallint,
	liveindicator bit,
	betteam nvarchar(10),
	creator int,
	refno bigint,
	winlostdate smalldatetime,
	betfrom nvarchar(1),
	betcheck nvarchar(50),
	checktime datetime,
	oddsspread smallmoney,
	actualrate float,
	matchid int,
	recommend int,
	mrecommend int,
	ruben tinyint,
	betid bigint,
	statuswinlost tinyint,
	modds smallmoney,
	bettype smallint,
	betdaqid bigint,
	actual_stake money,
	currency tinyint,
	transdesc nvarchar(300),
	sdiscount decimal(9, 8),
	scomm money,
	spositiontaking smallmoney,
	swinlost money,
	srecommend int,
	username nvarchar(50),
	virtualrate float,
	oddstype tinyint,
	statusid tinyint,
	currency2 tinyint
 )


GO
GRANT EXECUTE ON [dbo].[PIH_BettransIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[PIH_BettransIns] TO [vnteam] 

 