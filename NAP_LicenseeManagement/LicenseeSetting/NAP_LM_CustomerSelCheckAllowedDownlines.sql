/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet,bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_CustomerSelCheckAllowedDownlines]  
	@custid			INT = 0   
	,@AgentID		INT = 0
	,@sporttype		INT = 0 
	,@isUpdatePT	BIT	= 0 
	,@IsSetting		TINYINT = 0 
	,@Language		VARCHAR(2) = 'E'  
	,@ErrCode		INT = 0 OUTPUT  
	,@ErrMsg		NVARCHAR(200) = '' OUTPUT    
AS    
/*  
Created by: Elodie
Date: 2015-01-12
Task : Check Allowed downlines during peak hour at weekend for Licensee
DB: DBAGE/bodb02, DBCUST/CUSTDB        
Original SP: Acc_CustomerSelCheckAllowedDownlines        

Revisions:       
	- 20200114@Johnson: set threshold = 500k for normal [redmine: #126572]
	- 202202220@Elodie: Apply DCS for SB [RedmineID: #167898] 
	- 20230717@Winfred: Enhance performace  [redmine:#191470]
	- 20230722@Winfred: NAP LM - Enhance performance when adjusting betlimit for big licensees  [redmine:#195079]
Param's Explanation: 
	+ @sporttype: 1: Sportsbook 
	+ @IsSetting: 1: Bet Limit , 0 : Order
 
*/  
  
BEGIN    
	SET NOCOUNT ON  
	  
	DECLARE @LimitDownlinesMin INT,   --Peak hours
		@LimitDownlinesMax INT,		  -- Normal 
		@LimitDownlines INT,  
		@TotalDownlines INT  
	  
	SET @LimitDownlinesMin = 20000  
	SET @LimitDownlinesMax = 500000  
		 
	IF @sporttype = 1  AND @isUpdatePT = 1 -- Sportsbook 
	BEGIN
		SELECT	 @LimitDownlinesMin = 20000 -- Change value due to apply DCS for SB
				,@LimitDownlinesMax = 500000 
	END  
	  
	--GET TOTALDOWNLINE  
	SET @TotalDownlines=1  
	IF @IsSetting = 1
	BEGIN
		IF @AgentID = 0
		BEGIN
			SELECT  @TotalDownlines = count(1)   
			FROM Custinfo t WITH (NOLOCK)  
				CROSS APPLY (SELECT TOP 1 CustID FROM Dep_CustSettingMode cm WHERE custid = t.CustID AND IsGroupedBetLimit = 0) q
			WHERE srecommend=@custID AND roleid = 1
		END
		ELSE
		BEGIN
			SELECT  @TotalDownlines = count(1)   
			FROM Custinfo t WITH (NOLOCK)  
				CROSS APPLY (SELECT TOP 1 CustID FROM Dep_CustSettingMode cm WHERE custid = t.CustID AND IsGroupedBetLimit = 0) q
			WHERE recommend=@AgentID AND roleid = 1
		END
	END 
	ELSE
	BEGIN
		SELECT  @TotalDownlines = count(1)   
		FROM Custinfo WITH (NOLOCK)  
		WHERE srecommend=@custID  	
	END
	SELECT  @LimitDownlines = CASE  WHEN datename(weekday, getdate()) in ('Saturday','Sunday') and   
											datepart(hour, getdate()) between 7 and  14 --Weekend's peak hour, from 7PM - 2AM (GMT+8)  
										THEN  @LimitDownlinesMin  
									ELSE @LimitDownlinesMax  END   
	  
	IF @TotalDownlines >  @LimitDownlines  
	BEGIN       
		SELECT	@ErrMsg= CASE @Language WHEN 'E' THEN 'This function is not available during peak hour since it might affect the performance of the whole system. Please contact IT for further assistance.'
										ELSE [dbo].[f_Get_MsgNamebyMsgID](90010,@Language) END
				,@ErrCode = 113 	     
	END   
END   
  
GO