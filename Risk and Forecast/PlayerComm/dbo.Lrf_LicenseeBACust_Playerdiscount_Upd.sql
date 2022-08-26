/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeBACust_Playerdiscount_Upd]
	@CustID INT,--member
	@SBComm [decimal](9,8),
	@ParlayComm [decimal](9,8)
AS
/*
Created: 20151007@Jim
Task : Update SB Commission,Parlay Commission WHEN BA is ON/OFF
DB: DBCUST/CustDB
Revision :
	- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898] 
*/
 

BEGIN
	DECLARE @AgentID INT
	SELECT @AgentID = recommend FROM custinfo WITH(NOLOCK) WHERE custid = @CustID

	DECLARE @SportBetype TABLE (sporttype SMALLINT, bettype INT)
	INSERT INTO @SportBetype (sporttype,bettype)
	SELECT SportType,bettype
	FROM Dep_ProductSetting d WITH(NOLOCK)
		INNER JOIN Dep_ProductSettingDetail dp WITH(NOLOCK) 
			ON d.ProductSettingID = dp.ProductSettingID
	WHERE d.ProductID = 1
		AND SettingType = 9

	--move to invidual setting
	INSERT INTO dbo.Dep_CustDiscountSetting_Member
		(
		 CustID
		,SportType
		,BetType
		,PlayerDiscount
		,AgentDiscount
		,MasterDiscount
		,SuperDiscount
		)
	SELECT @CustID
		,grp.SportType
		,grp.BetType
		,grp.PlayerDiscount
		,grp.AgentDiscount
		,grp.MasterDiscount
		,grp.SuperDiscount
	FROM dbo.Dep_CustDiscountGroupSetting_Member grp WITH(NOLOCK)
		LEFT JOIN dbo.Dep_CustDiscountSetting_Member cs WITH(NOLOCK) 
			ON cs.custid = @custid
			AND cs.sporttype = grp.sporttype
			AND cs.bettype = grp.bettype
	WHERE AgentID = @AgentID
		AND cs.custid IS NULL

	UPDATE cs 
	SET cs.PlayerDiscount = @ParlayComm
	FROM Dep_CustDiscountSetting_Member cs WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @SportBetype t 
			ON cs.SportType = t.sporttype 
			AND cs.BetType = t.bettype
	WHERE cs.custid = @custid
		AND cs.bettype = 9

	UPDATE cs 
	SET cs.PlayerDiscount = @SBComm
	FROM Dep_CustDiscountSetting_Member cs WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @SportBetype t 
			ON cs.SportType = t.sporttype 
			AND cs.BetType = t.bettype
	WHERE cs.custid = @custid
		AND cs.bettype <> 9

	UPDATE d
	SET IsGroupedComm = 0
	FROM Dep_CustSettingMode d WITH(ROWLOCK, UPDLOCK) 
	WHERE custid = @CustID AND IsGroupedComm = 1
END	
GO
