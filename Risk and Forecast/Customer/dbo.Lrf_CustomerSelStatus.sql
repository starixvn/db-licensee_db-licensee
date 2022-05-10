/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerSelStatus]
    @CustID INT
AS 
/*
Created: 20101210@Henry
Task : SELECT customer's status
DB: DB052.bodb02
Original: Acc_CustomerSelStatus

Revisions:
   - 20130719@Jim: remove suspended status 
   - 20131023@Jim: Allow users to enable/ disable Casino games for specific players 
   - 20180228@Vicky: Remove LC from product list [Redmine: #85965]
   - 20180420@Akex : Return more currencyId [Redmine:93961]
   - 20180809@Amanda: Remove Racing [RedmineID: #99378]
   - 20190926@Eden: 3rd party products - Remove InActive Products Phase 2 [Redmine: #118699]
   - 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
Param's Explanation:
    - @CustID: customer id.   
*/
BEGIN
    SET NOCOUNT ON
    DECLARE @agentid INT, @roleid TINYINT, @IsInternal BIT
    
    SELECT @roleid = roleid, @agentid = recommend
    FROM custinfo WITH (NOLOCK)
    WHERE custid = @CustID
    --Get Internal status
    SELECT @IsInternal = CASE @roleid WHEN 4 THEN (SELECT isnull(IsInternal, 0) FROM custSuper WITH (NOLOCK) WHERE custid = @custid)
                                      WHEN 3 THEN (SELECT isnull(IsInternal, 0) FROM custMaster WITH (NOLOCK) WHERE custid = @custid)
                                      WHEN 2 THEN (SELECT isnull(IsInternal, 0) FROM custAgent WITH (NOLOCK) WHERE custid = @custid)
                                      WHEN 1 THEN (SELECT isnull(IsInternal, 0) FROM custAgent WITH (NOLOCK) WHERE custid = @agentid)
                                      ELSE 0 END 
    
    SELECT  ISNULL (closed,0) As Closed,
            ISNULL (autosuspend,0) As AutoSuspend,  
            ISNULL (cm.DisableAutoMPT ,0) As DisableAutoMPT, 
            ISNULL(DisableOutright,0) AS DisableOutright,
            ISNULL(srecommend, 0) AS SRecommend,
            ISNULL(mrecommend, 0) AS MRecommend,
            ISNULL(recommend, 0) as ARecommend,
            1 AS IsAdminCanViewVNIP,
		  ci.currency as CurrencyID,
            @IsInternal AS IsInternal
    FROM custinfo AS ci WITH (nolock)
        LEFT JOIN CustMaster AS cm WITH (NOLOCK) ON ci.CustID = cm.custid
    WHERE ci.CustID = @CustID

END
GO
