CREATE TABLE avatar (id INTEGER PRIMARY KEY,
                     user_id INTEGER,
                     name TEXT,
                     address TEXT,
                     attributes INTEGER,
                     UNIQUE(name, address));

CREATE TABLE room (id INTEGER PRIMARY KEY,
                   creator_id INTEGER,
                   creator_name TEXT,
                   creator_address TEXT,
                   room_name TEXT,
                   room_topic TEXT,
                   room_password TEXT,
                   room_prefix TEXT,
                   room_address TEXT,
                   room_attributes INTEGER,
                   room_max_size INTEGER,
                   room_message_id INTEGER,
                   created_at INTEGER,
                   node_level INTEGER,
                   UNIQUE(room_name, room_address),
                   FOREIGN KEY(creator_id) REFERENCES avatar(id));

CREATE TABLE room_administrator (admin_avatar_id INTEGER,
                                 room_id INTEGER,
                                 PRIMARY KEY(admin_avatar_id, room_id),
                                 FOREIGN KEY(admin_avatar_id) REFERENCES avatar(id) ON DELETE CASCADE,
                                 FOREIGN KEY(room_id) REFERENCES room(id) ON DELETE CASCADE);

CREATE TABLE room_moderator (moderator_avatar_id INTEGER,
                             room_id INTEGER,
                             PRIMARY KEY(moderator_avatar_id, room_id),
                             FOREIGN KEY(moderator_avatar_id) REFERENCES avatar(id) ON DELETE CASCADE,
                             FOREIGN KEY(room_id) REFERENCES room(id) ON DELETE CASCADE);

CREATE TABLE room_ban (banned_avatar_id INTEGER,
                       room_id INTEGER,
                       PRIMARY KEY(banned_avatar_id, room_id),
                       FOREIGN KEY(banned_avatar_id) REFERENCES avatar(id) ON DELETE CASCADE,
                       FOREIGN KEY(room_id) REFERENCES room(id) ON DELETE CASCADE);

CREATE TABLE room_invite (invited_avatar_id INTEGER,
                          room_id INTEGER,
                          PRIMARY KEY(invited_avatar_id, room_id),
                          FOREIGN KEY(invited_avatar_id) REFERENCES avatar(id) ON DELETE CASCADE,
                          FOREIGN KEY(room_id) REFERENCES room(id) ON DELETE CASCADE);

CREATE TABLE persistent_message (id INTEGER PRIMARY KEY,
                                 avatar_id INTEGER,
                                 from_name TEXT,
                                 from_address TEXT,
                                 subject TEXT,
                                 sent_time INTEGER,
                                 status INTEGER,
                                 folder TEXT,
                                 category TEXT,
                                 message TEXT,
                                 oob BLOB,
                                 FOREIGN KEY(avatar_id) REFERENCES avatar(id) ON DELETE CASCADE);

CREATE TABLE friend (avatar_id INTEGER,
                     friend_avatar_id INTEGER,
                     comment TEXT,
                     PRIMARY KEY(avatar_id, friend_avatar_id),
                     FOREIGN KEY(avatar_id) REFERENCES avatar(id) ON DELETE CASCADE,
                     FOREIGN KEY(friend_avatar_id) REFERENCES avatar(id) ON DELETE CASCADE);

CREATE TABLE ignore (avatar_id INTEGER,
                     ignore_avatar_id INTEGER,
                     PRIMARY KEY(avatar_id, ignore_avatar_id)
                     FOREIGN KEY(avatar_id) REFERENCES avatar(id) ON DELETE CASCADE,
                     FOREIGN KEY(ignore_avatar_id) REFERENCES avatar(id) ON DELETE CASCADE);
