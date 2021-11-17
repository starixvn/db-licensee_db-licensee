ALTER PROCEDURE [dbo].[Acc_BettransXMLIns]  
	@strXML NVARCHAR(MAX) 
AS  
/*  Created: Henry  
	Date: 2012-03-02
    TASk : Insert data to bettrans in Kahnawake server using XML
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  

DECLARE @intDocHandle INT

--Create an internal representation of the XML document.      
EXEC sp_xml_preparedocument @intDocHandle OUTPUT, @strXML      
  
--Delete before insert      
DELETE FROM bettrans WITH (ROWLOCK,UPDLOCK)      
WHERE Transid IN (      
	SELECT transid FROM OPENXML(@intDocHandle,'root/bettrans',2)      
	WITH (transid BIGINT)      
)     

INSERT INTO [dbo].[bettrans]      
           (
	[transid]      
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
	,[ip]      
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
           )      
SELECT       
	[transid]      
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
	,[ip]      
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
 WITH (      
	transid bigint,      
	custid int,      
	transdate datetime,      
	oddsid int,      
	hdp1 smallmoney,      
	hdp2 smallmoney,      
	odds smallmoney,      
	stake money,      
	status nvarchar(10),      
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
	betdaqid bigint ,      
	actual_stake money,      
	currency tinyint,      
	ip nvarchar(15),      
	transdesc nvarchar(300),      
	sdiscount decimal(9, 8),      
	scomm money,      
	spositiontaking smallmoney,      
	swinlost money,      
	srecommend int,      
	username nvarchar(50),      
	virtualrate float,      
	oddstype tinyint ,      
	statusid tinyint ,      
	currency2 tinyint      
  )  
  
END   

GO
GRANT EXECUTE ON [dbo].[Acc_BettransXMLIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BettransXMLIns] TO [vnteam] 

  