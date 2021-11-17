ALTER PROCEDURE [dbo].[Acc_BettransIns]  
	@Transid BIGINT,
	@CustID INT,
	@Transdate DATETIME,
	@Oddsid INT,
	@hdp1 SMALLMONEY = 0,
	@hdp2 SMALLMONEY = 0,
	@odds SMALLMONEY = 0,
	@stake MONEY,
	@status NVARCHAR(10) = NULL,
	@winlost money = 0,
	@awinlost money =0,
	@mwinlost money=0,
	@playercomm money=0,
	@comm money=0,
	@acomm money=0,
	@apositiontaking smallmoney=0,
	@mpositiontaking smallmoney=0,
	@tpositiontaking smallmoney=0,
	@playerdiscount decimal (9, 8)=0,
	@discount decimal(9, 8)=0,
	@adiscount decimal(9, 8)=0,
	@livehomescore smallint=0,
	@liveawayscore smallint=0,
	@liveindicator bit=0,
	@betteam nvarchar(10) = NULL,
	@creator int=0,
	@refno bigint,
	@winlostdate smalldatetime = null,
	@betfrom nvarchar(1) = 'i',
	@betcheck nvarchar(50) =null,
	@checktime datetime = NULL,
	@oddsspread smallmoney = NULL,
	@actualrate float = NULL,
	@matchid int = NULL,
	@recommend int,
	@mrecommend int,
	@ruben tinyint = 0,
	@betid bigint = NULL,
	@statuswinlost tinyint = NULL,
	@modds smallmoney =1,
	@bettype smallint = NULL,
	@betdaqid bigint = NULL,
	@actual_stake money = 0,
	@currency tinyint  = NULL,
	@ip nvarchar(15) =NULL,
	@transdesc nvarchar(300) = NULL,
	@sdiscount decimal(9, 8) = NULL,
	@scomm money =0,
	@spositiontaking smallmoney =0,
	@swinlost money = 0,
	@srecommend int,
	@Username nvarchar(50) = NULL,
	@virtualrate float=0,
	@oddstype tinyint = NULL,
	@statusID tinyint = NULL,
	@currency2 tinyint = NULL
AS  
/*  Created: Henry  
	Date: 2012-02-21
    TASk : Insert data to bettrans in Kahnawake server
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	--Delete before insert
	IF EXISTS (SELECT 1 FROM bettrans WITH (NOLOCK) WHERE Transid = @Transid)
	BEGIN
		DELETE FROM bettrans WITH (ROWLOCK,UPDLOCK)
		WHERE Transid = @Transid
	END

	INSERT INTO [dbo].[bettrans]
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
           ,[currency2])
     VALUES	
     (
		@Transid,
		@CustID,
		@Transdate,
		@Oddsid,
		@hdp1,
		@hdp2,
		@odds,
		@stake,
		@status,
		@winlost,
		@awinlost,
		@mwinlost,
		@playercomm,
		@comm,
		@acomm,
		@apositiontaking,
		@mpositiontaking,
		@tpositiontaking,
		@playerdiscount,
		@discount,
		@adiscount,
		@livehomescore,
		@liveawayscore,
		@liveindicator,
		@betteam,
		@creator,
		@refno,
		@winlostdate,
		@betfrom,
		@betcheck,
		@checktime,
		@oddsspread,
		@actualrate,
		@matchid,
		@recommend,
		@mrecommend,
		@ruben,
		@betid,
		@statuswinlost,
		@modds,
		@bettype,
		@betdaqid,
		@actual_stake,
		@currency,
		@ip,
		@transdesc,
		@sdiscount,
		@scomm,
		@spositiontaking,
		@swinlost,
		@srecommend,
		@Username,
		@virtualrate,
		@oddstype,
		@statusID,
		@currency2
     )

END   

GO
GRANT EXECUTE ON [dbo].[Acc_BettransIns] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BettransIns] TO [vnteam] 

 