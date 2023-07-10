# Velocity API specification `v 1.0`

This is a proposal for the `1.0` version of the Velocity API specification.

The Velocity API uses `JSON` as its language.

The API is divided into several namespaces:

- [`/u`](#namespace-u): User and group management

### Errors

If the API enconters some kind of error, it will respond with a http-response code in a non-200 range and an error as follows:

```json
{
    "error": "<Some error message>"
}
```

Some additional fields may be added to the error response depending on calls but this layout is guaranteed.

Some http-response codes are fixed:

- `400 - Bad Request`: The request is missing fields

- `403 - Forbidden`: The request is missing the `authkey` for privileged actions

# Users and Groups: `/u` <a name="namespace-u"></a>

Velocity's concept of users and groups is similar to that of Unix. Everything is UUID-based to randomize the user- and group-ids to minimize attack vectors by guessing other users user-ids. Permissions, vm and data pools are always connected to groups due to them being able to be shared across users with a fair amount of granularity.

### User

Each user is identified by its unique UUID, its username and password.

Every user automatically gets assigned a group using the users `username`.

### Group

Velocity works with groups. There are some special groups with specific privileges:

- `administrator`: Has permission to do everything, users in this group are superusers.

- `usermanager`: Users that are in this group have the permission to create new users and groups and assign users to groups except `administrator`.

### Available endpoints

Authentication:

- [`/u/auth` - POST](#post-u-auth): Authenticate as a user

- [`/u/auth` - DELETE](#delete-u-auth): Log out the current user

- [`/u/auth` - PATCH](#patch-u-auth): Reauthenticate

User and group management:

- [`/u/user` - PUT](#put-u-user): Create a new user

- [`/u/user` - DELETE](#delete-u-user): Remove a user

- [`/u/group` - PUT](#put-u-group): Create a new group

- [`/u/group` - DELETE](#delete-u-group): Remove a group

- [`/u/group/assign` - PUT](#put-u-group-assign): Assign a user to a group

- [`/u/group/assign` - DELETE](#delete-u-group-assign): Remove group membership

## `/u/auth` - POST <a name="post-u-auth"></a>

Velocity's authentication model works using so-called 'authkeys'. Every user that is currently authenticated gets such a key that has a certain validity window. Every privileged action that requires authentication requires this authkey to be sent with the request. To obtain such an authkey, a user can issue an authentication to this endpoint.

**Request:**

```json
{
    "username": "<username>",
    "password": "<password>"
}
```

The password and username get transmitted in plaintext. It is assumed that the connection to the API uses HTTPS.

**Response:**

- `200`: Authenticated

- `403 - Forbidden`: Authentication failed - username or password do not match

```json
200
{
    "authkey": "<authkey>",
    "expires": "<unix timestamp>"
}
```

Every authkey has an expiration date that is transmitted in the unix timestamp format. The key has to be renewed before this date is passed for the key to stay valid.

## `/u/auth` - DELETE <a name="delete-u-auth"></a>

If a user desires to drop the current `authkey` immediately, this endpoint can be used for that.

**Request:**

```json
{
    "authkey": "<authkey>"
}
```

**Response:**

- `200`: Authkey dropped

> **Note**
> 
> For security reasons, dropping a non-existing authkey does still result in a `200` response code.

## `/u/auth` - PATCH <a name="patch-u-auth"></a>

If an authkey lease is about to expire, this call can be used to create a new authkey using the expiring key.

> **Note**
> 
> This will immediately drop the old authkey in favor of the newly generated one.

**Request:**

```json
{
    "authkey": "<authkey>"
}
```

**Response:**

- `200`: Authkey refreshed

- `403`: Tried to renew a non-existing / expired authkey

```json
200
{
    "authkey": "<new authkey>",
    "expires": "<unix timestamp>"
}
```

## `/u/user` - PUT <a name="put-u-user"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can create users

This call automatically creates a new group with the groupname set to `<username>` and assigns the new user to that.

**Request:**

```json
{
    "authkey": "<authkey>",
    "username": "<username>",
    "password": "<password>",
    "groups": ["<GID>"]
}
```

The groups field can be an empty array.

**Response:**

- `200`: User created

- `401 - Unauthorized`: The current user is not allowed to create new users

- `409 - Conflict`: A user with the supplied `username` does already exist

```json
200
{
    "uid": "<UID>",
    "username": "<username>",
    "groups": ["<GID>"]
}
```

## `/u/user` - DELETE <a name="delete-u-user"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can remove users

This call removes the user with the supplied `UID`. This also removes the user's group that is named the same as the user and all of its VMs and images.

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>"
}
```

**Response:**

- `200`: User removed

- `401 - Unauthorized`: The current user is not allowed to remove users

## `/u/group` - PUT <a id="put-u-group"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can create groups

**Request:**

```json
{
    "authkey": "<authkey>",
    "groupname": "<groupname>"
}
```

**Response:**

- `200`: Group created

- `401 - Unauthorized`: The current user is not allowed to create new groups

- `409 - Conflict`: A group with the supplied `groupname` does already exist

```json
200
{
    "gid": "<GID>",
    "groupname": "<groupname>"
}
```

## `/u/group` - DELETE <a name="delete-u-group"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can remove groups

This call removes all the VMs and images owned by this group.

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>"
}
```

**Response:**

- `200`: Group removed

- `401 - Unauthorized`: The current user is not allowed to remove users

## `/u/group/assign` - PUT <a id="put-u-group-assign"></a>

Assign a user to groups:

> **Note**
> 
> Only users that are in the `usermanager` group can assign users to groups

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

**Response:**

- `200`: Groups added

- `401 - Unauthorized`: The current user is not allowed to create new groups

- `403 - Forbidden`: A user in `usermanager` tried to assign to `administrator` group

```json
200
{
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

The response lets the caller know which groups the user now belongs to.

## `/u/group/assign` - DELETE <a name="delete-u-group-assign"></a>

Remove a user from groups:

> **Note**
> 
> Only users that are in the `usermanager` group can remove users from groups

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

**Response:**

- `200`: User removed from groups

- `401 - Unauthorized`: The current user is not allowed to remove from groups

- `403 - Forbidden`: A user in `usermanager` tried to remove from `administrator` group

```json
200
{
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

The response lets the caller know which groups the user now belongs to.
